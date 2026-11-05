# Why the v2 layout: comparison with operate-iac

This compares the proposed layout in this folder (v2) with the current `operate-iac` repo
(Terraform + Terragrunt, five stacks). It covers what improves, what gets worse, and what the
move would cost.

Numbers for operate-iac come from the repo as it stands: `hub/`, `shared/`, `client/` and
`app-services/` root modules, `*/environments/**/terragrunt.hcl` and `.azure-pipelines/`.

## Summary

| | operate-iac (today) | v2 |
| --- | --- | --- |
| Tooling | Terraform + Terragrunt | Terraform only |
| Unit of state | One stack per (region, env): `shared` = 158 resources in one state | One **service** per (region, env): ~5-15 resources each |
| Cross-stack values | 36 `dependency` blocks reading the whole upstream state, each with hand-written `mock_outputs` | `data` sources that look up one resource by name |
| Per-environment config | `terragrunt.hcl` per stack per env: provider, backend, subscription ID, mocks and inputs, all copied | One `global/global.tfvars` + a small `env/<env>.tfvars` per service |
| Provider config | Copied into 35 `terragrunt.hcl` files, and the copies have drifted | One `providers.tf` per service, identical apart from deliberate differences |
| Apply order | Implicit in Terragrunt dependencies + pipeline structure | Explicit `dependsOn` list in each pipeline file |
| Pipeline review | Plan and apply per stack | Plan every service, review, then apply the **saved** plans; untouched services are skipped |

## What gets better

### 1. Smaller states, smaller blast radius

In operate-iac each stack is one root module and one state per (region, env). `shared` holds
158 resources (SQL, App Gateway, app cluster, Prizm, Seq, Key Vaults, storage, networking).
Changing a Seq VM size means planning, locking and applying all 158, and any unrelated drift
in that state shows up in the same plan.

In v2 every service has its own state: `seq/`, `sql-server/`, `app-gateway/` and so on.
- A change only plans and locks the service it touches.
- An apply that goes wrong can only damage that one service.
- Plans are short enough to review properly.
- Two people can work on different services in the same environment without waiting on each
  other's state lock.

The customer stack splits the same way. `customer-data` (SQL database, storage, Key Vault)
holds the customer's stateful resources apart from `customer-app` (VMs), so app VMs can be
rebuilt without the data resources ever appearing in the plan.

### 2. No more reading whole upstream states

A Terragrunt `dependency "hub"` block runs `terraform output` against the hub's state, so the
shared and client pipelines need read access to all of the hub state. That includes anything
sensitive in it: the hub already exposes `sharedo_admin_pw_secret_id` to every consumer.

v2 has no `dependency` blocks and no `terraform_remote_state`. A service finds what it needs
with a `data` source that reads **one** resource, using the caller's own Azure RBAC:

```hcl
data "azurerm_subnet" "vm" {
  name                 = "snet-operate-shared-vm-${local.g.suffix}"
  virtual_network_name = "vnet-operate-shared-${local.g.suffix}"
  resource_group_name  = "rg-operate-shared-networking-${local.g.suffix}"
}
```

Names come from the existing naming convention
(`{abbrev}-operate-{workload}-{env}-{region}-{instance}`), so nothing new needs inventing.

### 3. No mock outputs to maintain

Each of the 36 `dependency` blocks has a hand-written `mock_outputs` map so that `plan` works
before the upstream stack exists. Those maps are a second, unchecked copy of the upstream
outputs:
- When a hub output changes shape, every mock must be updated by hand.
- If one isn't, the plan still runs, against values that no longer reflect the real outputs.

The `client` mocks are already mostly empty strings.

v2 has nothing to mock. A data source either finds the real resource or fails the plan.

### 4. Configuration written once instead of copied

Each operate-iac `terragrunt.hcl` repeats:
- the `provider "azurerm"` block
- the `remote_state` block
- the subscription ID, in two places
- the region and environment

Across 35 files, the copies have drifted. For example, `purge_soft_delete_on_destroy` is
`true` in 12 files and `false` in 22, and nothing in the code says whether that difference
is intentional.

In v2:
- **Shared values:** `global/global.tfvars` holds `global`, which is the same everywhere, and
  `environments`, with one entry per subscription: subscription ID, suffix, VNet octet, AD
  IP and tags. Both are typed in `variables.tf`, so a misspelt key fails before plan.
- **Per-service values:** each `env/<env>.tfvars` holds only that service's own values
  (sizes, counts, retention).
- **Environment name:** `scripts/terraform.sh` takes it from the tfvars file name, so a file
  can't target the wrong environment.
- **Backend:** generated from the target, so a job can only ever touch its own state.

v2's environment keys (`prod-uks`) match the operate-iac rule that one subscription is
exactly one (region, environment). A new region is a new entry in `environments`, not a new
folder tree.

### 5. Folder names say what the service does

operate-iac nests resources by stack and then by file (`shared/compute_prizm.tf`,
`shared/database_sql.tf`). To find what owns the Datadog SQL monitor, you need to know it
lives in `shared/` in a file named `monitoring_datadog_sql.tf`.

v2 puts every service at the top level under a plain name: `network`, `key-vault`,
`sql-server`, `sql-monitoring`, `databricks`, `prizm`. Only the per-customer
(`customer-*`) and App Service (`app-services-*`) services keep a prefix, because their
names would otherwise clash with `network`.

Hub and shared networking are one service (`network`), as are the two platform Key Vaults
(`key-vault`). Hub and shared networking are always changed together, and the shared→hub
peering now references the hub VNet directly instead of through a dependency output.

### 6. Pipelines that plan, wait for review, then apply exactly what was reviewed

`pipelines/` has three chained Azure DevOps pipelines: `platform` → `app-services` and
`customer`. For each environment, dev → uat → prod, a run does this:

1. **Plan** every service in parallel. A plan with changes is published as an artifact.
2. **Apply** on `main` only, and only if something changed. The run waits for approval on
   the `operate-iac-<env>` environment, then applies the **saved** plan files in
   `dependsOn` order. The apply is exactly what the reviewer saw. If anything changed in
   between, Terraform refuses the stale plan instead of applying something different.

Behaviour that falls out of this:
- **No-op services are skipped.** If no plan in an environment has changes, the apply stage
  doesn't run and no approval is requested.
- **PRs plan every environment and apply nothing.** This gives a full preview of the change.
- **Explicit order.** Within a pipeline, ordering is a visible `dependsOn` list (e.g. `seq`
  waits for `private-dns` because it writes its DNS record there), not something Terragrunt
  works out from `config_path` strings.
- **Missing config means "not deployed here".** If a service or customer has no tfvars for
  an environment, it's skipped instead of failing.

### 7. One tool fewer

v2 is plain Terraform. That removes:
- Terragrunt itself, and its version pin on the CI runner
  (`register-ci-runner-agent.ps1 -TerragruntVersion`)
- `root.hcl` code generation
- `.terragrunt-cache`
- `find_in_parent_folders` / `get_repo_root()` path handling

Anyone who knows Terraform can read a v2 service folder without learning Terragrunt's
include, merge and mock rules.

## What gets worse, and the mitigations

| Trade-off | Detail | Mitigation |
| --- | --- | --- |
| **Resource names become the contract** | Renaming a resource breaks every data lookup of it. Terragrunt outputs had the same problem, but the mocks would hide it until apply. | A data-source miss fails the plan, so it's caught early. A shared `modules/names` module would make both sides use the same string. |
| **More states and pipeline jobs** | ~20 services per environment instead of 4 stacks, plus one per (customer, service). | Plans run in parallel; services with no changes skip apply. |
| **Duplicated boilerplate** | Each service repeats the `global` / `environments` / `environment` variables and `providers.tf`. | Symlink one `_common/globals.tf` and `providers.tf` into each service, or add a CI check that they match. |
| **A brand-new environment can't be fully planned in one go** | Downstream data lookups fail until upstream services exist, which is the job Terragrunt mocks did. | Pipelines apply in `dependsOn` order, so a first rollout succeeds across one run per tier. |
| **Customer list in two places** | `customer.yml` lists customers, and so do the tfvars folders. | Missing tfvars are skipped, so the only risk is forgetting to add a customer to the pipeline list. |
| **Platform pipeline on Microsoft-hosted agents** | It has to be, because `ci-runner` creates the self-hosted agents. Data-plane operations behind firewalls (e.g. writing Key Vault secrets) would fail there. | No platform service does data-plane work today; anything that needs to belongs in a self-hosted pipeline. |

## What v2 does not cover yet

v2 is a **layout example**, not a port. Before it could replace operate-iac:

- **Service contents are stubs.** Each `main.tf` names the operate-iac files it replaces
  (`# From operate-iac: ...`) and builds a representative subset of their resources.
- **Only UK South dev / uat / prod.** operate-iac has 10 (region, env) subscriptions across
  four regions, plus `gov`, `ppd` and `sbx`. Each would become an `environments` entry.
- **Not yet carried over:**
  - the `security/` stack
  - Packer images
  - `client-app-deploy`, `client-destroy` and `recreate-client-database`
  - `initialize-subscription.ps1`, which creates one state container per stack today; v2
    expects a single `tfstate` container
  - the CI runner tooling install
- **`scripts/terraform.sh` does not exist yet.** The pipelines call it, as described in the
  README.
- **Never run against Azure.** The YAML and Terraform pass syntax checks and
  `terraform validate`, but no plan or apply has been run.
- **State migration is the largest cost.** Each environment's `hub`, `shared`, `client` and
  `app-services` state has to be split into per-service states:
  - Moves within one state use `moved` blocks.
  - Moves into a new service's state use `import` blocks, as the `network/migration.tf` and
    `key-vault/migration.tf` examples show.
  - Every first plan must show only imports and moves, with no adds or destroys.

  That's about 220 hub + shared resources per subscription across 10 subscriptions, plus
  about 50 per customer deployment.

## Recommendation

Adopt v2 incrementally rather than as one cut-over:

1. Write `scripts/terraform.sh` and run the v2 pipelines against a sandbox (`sbx`) subscription.
2. Move one low-risk service out of the `shared` stack (e.g. `sql-monitoring`) and confirm the
   import-only plan in every environment.
3. Carry on service by service, deleting the matching code and state from the Terragrunt
   stack each time, so both layouts can run side by side until the last service is moved.
