# operate-iac - Terragrunt layout, v3 (example, UK South: dev / uat / prod)

v3 keeps v2's layout (one folder per service at the top level, one config per environment
inside it) and runs it with Terragrunt. Terragrunt takes over the jobs v2 needed a custom
script and hand-maintained pipeline ordering for: backend config, provider config, wiring
values in, and apply order.

```
root.hcl                         # included by every unit: versions, backend, provider, `context`
global/
  global.hcl                     # THE one global file: `global` + every entry of `environments`
.tool-versions                   # Terraform + Terragrunt versions (mise/asdf locally, CI reads it too)

network/                         # service = Terraform code + service.hcl + one unit per environment
  main.tf  variables.tf  outputs.tf  versions.tf
  service.hcl                    #   shared by every environment: source, apply order, common inputs
  env/dev-uks/terragrunt.hcl     #   folder name = environment; holds only this env's inputs
  env/uat-uks/terragrunt.hcl     #   (no folder = the service isn't deployed in that environment)
  env/prod-uks/terragrunt.hcl
key-vault/  domain-controller/  private-dns/  ci-runner/  image-gallery/  log-analytics/
sql-server/  storage/  databricks/  app-gateway/  app-cluster/  prizm/  seq/  sql-monitoring/
app-services-network/  app-services-web-app/

customer-network/  customer-data/  customer-app/
  env/<environment>/acme/terragrunt.hcl   # folder = environment, then customer

pipelines/
  deploy.yml                     # Azure DevOps: plan -> approve -> apply, per environment
  templates/
```

Same service folders as v2. The only change inside them: `env/<env>.tfvars` became
`env/<env>/terragrunt.hcl`, `providers.tf` became `versions.tf` (the provider is generated),
and the global/environments/environment variables became one `context` variable.

## How a unit gets its values

A **unit** is one `terragrunt.hcl`, i.e. one service in one environment (and customer). Its
path is its address, the same rule as v2's tfvars file names:

| Unit folder                         | service         | environment | customer | state key                                |
| ----------------------------------- | --------------- | ----------- | -------- | ---------------------------------------- |
| `network/env/prod-uks`              | `network`       | `prod-uks`  | -        | `network/terraform.tfstate`              |
| `customer-data/env/prod-uks/acme`   | `customer-data` | `prod-uks`  | `acme`   | `customer-data/acme/terraform.tfstate`   |

`root.hcl` reads the path and builds everything else from it:

- **`context`**: `global/global.hcl`'s `global` merged with `environments[<environment>]`, with
  `base_tags` and the environment's tags combined into `tags`. Every module takes this one
  typed variable and uses it as `local.g`, as in v2.
- **`customer`**: the customer folder name, for `customer-*` units.
- **Backend**: `stoprtfstate<env><loc>001` / `tfstate` / the state key above. The storage
  account is per subscription, so the key doesn't repeat the environment.
- **Provider**: one `provider "azurerm"` for every unit, so the settings can't drift between
  copies. Customer units may delete non-empty resource groups (for customer teardown);
  nothing else may.
- **Versions**: `terraform_binary = "terraform"` (Terragrunt 1.x defaults to OpenTofu), plus
  Terraform and Terragrunt version constraints.

Each unit then includes its service's `service.hcl` and adds only what differs in that
environment:

```hcl
# sql-server/env/prod-uks/terragrunt.hcl
include "root"    { path = find_in_parent_folders("root.hcl") }
include "service" { path = find_in_parent_folders("service.hcl") }

inputs = {
  elastic_pool = { capacity = 8, max_size_gb = 500, ... }
}
```

### Where does a value go?

- Same for every service and environment -> `global` in `global/global.hcl`
- Same for every service in one environment -> that entry of `environments` in `global/global.hcl`
- Same for one service in every environment -> `inputs` in `<service>/service.hcl`
- Specific to one service in one environment -> `<service>/env/<env>/terragrunt.hcl`
- Created by another service -> look it up by name with a `data` source in the module

## How services depend on each other

Two separate concerns, handled separately on purpose:

- **Order**: each `service.hcl` lists the units it must run after, in a `dependencies` block.
  The paths point at the same environment (and customer), e.g. `customer-data` waits for
  `customer-network/env/<env>/<customer>` and `sql-server/env/<env>`. A comment next to each
  non-obvious one says why (`seq` waits for `private-dns` because it writes its DNS record there).
- **Values**: modules still find other services' resources by name with `data` sources, as in v2.

v3 deliberately does **not** use Terragrunt `dependency` blocks to pass outputs between units:

- A `dependency` reads the upstream unit's *entire* state, secrets included. A `data` source
  reads one resource with the caller's own Azure RBAC.
- `dependency` needs hand-written `mock_outputs` so `plan` works before the upstream exists.
  Those mocks are an unchecked second copy of the outputs, and in operate-iac they have
  already drifted.

The cost is that resource names are the contract between services. Renaming one means
updating its lookups. A missed lookup fails at plan, not at apply.

## Running it

Terraform runs in the pipeline. To see what it would do locally (with `az login` and read
access to the subscription):

```bash
mise install                                      # or asdf - installs the .tool-versions pins

# One unit
cd sql-server/env/dev-uks && terragrunt plan

# Every unit in one environment, in dependency order
terragrunt run --all --filter './*/env/dev-uks' --filter './*/env/dev-uks/*' -- plan

# Just the order, no Azure access needed
terragrunt list --dag --filter './*/env/dev-uks' --filter './*/env/dev-uks/*'
```

## Pipeline (`pipelines/deploy.yml`)

1. **Checks**: `terraform fmt` and `terragrunt hcl fmt`.
2. For each environment, dev-uks -> uat-uks -> prod-uks:
   - **Plan**: `terragrunt run --all ... --out-dir plans -- plan` over that environment's
     units. The plans are published as an artifact.
   - **Apply**: on `main` only, after approval on the `operate-iac-<env>` Azure DevOps
     environment. `run --all --out-dir plans -- apply` applies exactly the saved plans, in
     dependency order. If anything changed since the plan, Terraform refuses the stale plan
     instead of applying something different.

PRs plan every environment and apply nothing.

**First deploy of a new environment**: run the pipeline with `firstDeploy` ticked. A plan of
the whole environment would fail, because downstream units look up resources that don't
exist yet. With `firstDeploy`, the plan stage is skipped and the apply stage plans and applies
each unit in dependency order instead, still behind the approval.

Setup per environment `<env>`:

| Thing                                             | Name                  |
| ------------------------------------------------- | --------------------- |
| Service connection (workload identity federation) | `sc-operate-iac-<env>` |
| Environment (approvals/checks)                    | `operate-iac-<env>`   |
| Variable group (secrets as `TF_VAR_*`)            | `operate-iac-<env>`   |

The pipeline uses Microsoft-hosted agents, because `ci-runner` creates the self-hosted ones.
Nothing here writes to a firewalled data plane, so they're enough. Anything that does, such as
Key Vault secrets, needs a self-hosted pool.

## Adding things

- **New environment**: add an entry under `environments` in `global/global.hcl`, then
  `env/<environment>/terragrunt.hcl` in each service it should run in (copy a sibling and
  change the inputs). Deploy it once with `firstDeploy`.
- **New service**: copy a sibling folder. Keep the four `.tf` files, `service.hcl` (fix the
  `dependencies` paths) and `env/`.
- **New customer**: add `env/<environment>/<customer>/terragrunt.hcl` in each `customer-*`
  service. The folder name is the customer name. No pipeline change is needed.

## Before first use

- **Lock files.** Commit a `.terraform.lock.hcl` in every unit so plan and apply use the same
  provider build. Terragrunt copies it back into the unit after `init`. Generate the files for
  both CI and laptops:
  `terragrunt run --all -- providers lock -platform=linux_amd64 -platform=darwin_arm64`.
- **State.** One `tfstate` container per subscription; `initialize-subscription.ps1` currently
  creates `hubtfstate` / `sharedtfstate` / `clienttfstate` instead. Moving existing state into
  per-service keys is the same job as for v2: `import` blocks for resources that move between
  states, `moved` blocks within one state, and an imports-only first plan.

## v2 -> v3 at a glance

| v2 (plain Terraform)                                 | v3 (Terragrunt)                                       |
| ---------------------------------------------------- | ----------------------------------------------------- |
| `env/<env>.tfvars`                                   | `env/<env>/terragrunt.hcl`                            |
| `global/global.tfvars`                               | `global/global.hcl`                                   |
| `providers.tf` copied in each service                | generated once by `root.hcl`                          |
| `scripts/terraform.sh` (backend, var passing; never written) | `root.hcl`                                    |
| apply order in three pipeline files (`dependsOn`)    | `dependencies` in each `service.hcl`; Terragrunt orders the run |
| three chained pipelines                              | one pipeline                                          |
| customers listed in `customer.yml`                   | customers are just folders                            |
| skips apply when nothing changed                     | always applies on main (a no-change plan is a no-op, but still asks for approval) |
