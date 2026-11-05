# operate-iac - plain Terraform layout, v2 (example, UK South: dev / uat / prod)

v2 drops the `hub/`, `shared/`, `client/` and `app-services/` folders: every service sits at
the top level, named for what it does (`network`, `databricks`, `sql-monitoring`, ...). Only the
per-customer and App Service services keep a prefix (`customer-`, `app-services-`), since their
names would otherwise clash (`customer-network`, `app-services-network` vs `network`).

Which pipeline runs a service - and so whether it is hub, shared, App Service or customer -
is set in `pipelines/`, not by the folder name.

```
global/
  global.tfvars                  # THE one global file: `global` + every entry of `environments`

# -- Platform: hub + shared (pipelines/platform.yml) ----------------------------
network/                         # service = providers.tf variables.tf main.tf outputs.tf + own state
  env/dev-uks.tfvars             #   file name = environment; holds only this service's values
  env/uat-uks.tfvars             #   (file must exist - even empty - for the service to run there)
  env/prod-uks.tfvars
                                 # hub + shared VNets, subnets, shared->hub peering
key-vault/                       # hub + shared platform key vaults
domain-controller/               # hub: AD DC (its IP is ad_private_ip in global.tfvars)
private-dns/                     # hub: private DNS zones incl. operate.internal
ci-runner/                       # hub: self-hosted pipeline agents
image-gallery/                   # hub: Compute Gallery for VM images
log-analytics/                   # hub: Log Analytics workspace
sql-server/                      # shared: SQL server + elastic pool
storage/  databricks/  app-gateway/  app-cluster/  prizm/  seq/
sql-monitoring/                  # shared: Datadog SQL monitoring of sql-server

# -- App Services (pipelines/app-services.yml) ----------------------------------
app-services-network/            # VNet integration subnet
app-services-web-app/            # App Service plan + Windows web app

# -- Customer, one state per (customer, service) (pipelines/customer.yml) -------
customer-network/  customer-data/  customer-app/
  env/<environment>/acme.tfvars  # folder = environment, file name = customer

pipelines/                       # Azure DevOps: chained pipelines (see Pipelines)
  platform.yml  app-services.yml  customer.yml
  templates/                     #   stages (plan/apply per environment), jobs, terraform steps

modules/                         # reusable building blocks (no provider/backend)
scripts/
  terraform.sh                   # runs any service: picks the tfvars by name, passes the rest
  bootstrap/                     # initialize-subscription.ps1, register-ci-runner-agent.ps1
  lib/                           # dot-sourced by operators/pipelines (az login)
  vm/windows, vm/linux           # runs ON the VM (IMDS only)
```

### v1 -> v2 folder map

| v1                                     | v2                                  |
| -------------------------------------- | ----------------------------------- |
| `hub/networking` + `shared/networking` | `network` (one state)               |
| `hub/key-vault` + `shared/key-vault`   | `key-vault` (one state)             |
| `hub/dns`                              | `private-dns`                       |
| `hub/monitoring`                       | `log-analytics`                     |
| `shared/sql`                           | `sql-server`                        |
| `shared/monitoring`                    | `sql-monitoring`                    |
| other `hub/<service>`, `shared/<service>` | `<service>`                      |
| `client/networking`                    | `customer-network`                  |
| `client/<service>`                     | `customer-<service>`                |
| `app-services/networking`              | `app-services-network`              |
| `app-services/app-service`             | `app-services-web-app`              |

Azure resource names (`vnet-operate-hub-...`, `rg-operate-shared-sql-...`) are unchanged, so
every by-name lookup still resolves - including in the two merged services.

**Migrating:** every service's state key now follows its v2 folder name, so move each v1
state blob to its new key before the first v2 run. The exception is `network` and `key-vault`:
they start with an empty state, and their `migration.tf` imports the existing hub + shared
resources on the first run, so that plan should show only imports - no adds or destroys. Once
all three environments are applied, delete both `migration.tf` files and the v1
`hub/networking`, `shared/networking`, `hub/key-vault` and `shared/key-vault` state blobs.
Never run destroy on those old states: it would delete the live VNets and vaults.

## How a service gets its values

Terraform only ever runs in the pipeline - nobody runs it by hand. Each pipeline job runs one
service for one environment (and customer) through `scripts/terraform.sh`:

```bash
scripts/terraform.sh network prod-uks plan
scripts/terraform.sh customer-data prod-uks acme plan
```

which runs, for example:

```bash
terraform -chdir=customer-data plan \
  -var-file=<repo>/global/global.tfvars \
  -var-file=env/prod-uks/acme.tfvars \
  -var environment=prod-uks -var customer=acme
```

- **The tfvars file name is the environment** (and, for `customer-*` services, the customer).
  The file never repeats it - the script passes `-var environment=` / `-var customer=` from the
  same name it picked the file by, so the two can't disagree. No file = the service isn't
  enabled there, and the script refuses to run.
- A service is per-customer when `env/<environment>` is a **folder** rather than a file; the
  script then requires the customer argument.
- `global/global.tfvars` sets `global` (same everywhere) and `environments` (a map with one
  entry per environment: subscription, suffix, VNet octet, AD server IP, env tags). Both are
  typed in every service's `variables.tf`, so a missing or misspelt key fails before plan, and
  `environment` must be one of the `environments` keys.
- `env/<environment>.tfvars` holds only the service's own values (sizes, counts, retention...).
- `main.tf` combines them once, at the top:

  ```hcl
  locals {
    g    = merge(var.global, var.environments[var.environment])
    tags = merge(local.g.base_tags, local.g.tags, { service = "Networking" })
  }
  ```

  Everything else uses `local.g.*` (`local.g.subscription_id`, `local.g.suffix`, `local.g.env`, ...).

| File           | Holds                                                           |
| -------------- | --------------------------------------------------------------- |
| `providers.tf` | `terraform {}` (versions) + `provider` (uses `local.g.subscription_id`) |
| `variables.tf` | `global`, `environments`, `environment` (+ `customer`) and the service's own inputs |
| `main.tf`      | `local.g`, upstream `data` lookups by name, resources          |
| `outputs.tf`   | values for pipelines and operators (not read by other services) |

## How services depend on each other

No `terraform_remote_state`. A service finds what it needs from another service by **name**,
with a data source - names are deterministic from the naming convention and `local.g.suffix`:

```hcl
data "azurerm_subnet" "vm" {
  name                 = "snet-operate-shared-vm-${local.g.suffix}"
  virtual_network_name = "vnet-operate-shared-${local.g.suffix}"
  resource_group_name  = "rg-operate-shared-networking-${local.g.suffix}"
}
```

Why: reading another service's state needs read access to *all* of it, secrets included.
A data source reads only that one resource, with the caller's own Azure RBAC. The cost is
that **resource names are the contract** - renaming one means updating its lookups.

Values that can't be looked up by name live in `global.tfvars` instead (e.g. the DC's
`ad_private_ip`, the `operate_dns_zone` name). Workloads own their own DNS records:
seq, prizm and app-cluster each write their A record into private-dns's `operate.internal` zone.

## Where does a value go?

- Same for every service and environment -> `global` in `global/global.tfvars`
- Same for every service in one environment -> that entry of `environments` in `global/global.tfvars`
- Specific to one service -> `<service>/env/<environment>.tfvars`
- Created by another service -> look it up by name with a `data` source

## Apply order

1. platform: `network` -> `key-vault`, hub services, shared services (exact order: `pipelines/platform.yml`)
2. `app-services-network` -> `app-services-web-app`
3. per customer: `customer-network` -> `customer-data` -> `customer-app`

The pipelines enforce this order - see below.

## Pipelines (Azure DevOps)

Three pipelines, chained so each runs only after the one it builds on:

```
operate-iac-platform  ──>  operate-iac-app-services
                      └─>  operate-iac-customer
```

| File                          | Pipeline name               | Runs for changes to                        | Also runs after |
| ----------------------------- | --------------------------- | ------------------------------------------ | --------------- |
| `pipelines/platform.yml`      | `operate-iac-platform`      | everything except `app-services-*` / `customer-*` (incl. `global/`, `scripts/`) | - |
| `pipelines/app-services.yml`  | `operate-iac-app-services`  | `app-services-*`                           | platform on main |
| `pipelines/customer.yml`      | `operate-iac-customer`      | `customer-*`                               | platform on main |

`global/` and `scripts/` only trigger platform; the chain carries the change down to the others.
Within platform, `dependsOn` replaces the old "all hub before shared" rule - e.g. `seq`
waits for `private-dns` because it writes its DNS record there.
All three also run when `pipelines/templates/` changes.

Each run, per environment (dev-uks -> uat-uks -> prod-uks):

1. **Plan** - every service (x customer) in parallel. A plan with changes is saved as an
   artifact; a service with no tfvars for that environment/customer is skipped.
2. **Apply** - main branch only, and only if some plan had changes. Applies the saved plans
   in each pipeline's `dependsOn` order. Upstream services with no changes don't hold it up.

PRs plan every environment and apply nothing. The next environment's plan starts only once
this one's apply has finished.

The service list and `dependsOn` order live in each pipeline file; `pipelines/templates/` holds
the shared stages and the steps that call `scripts/terraform.sh`.

### Setup in Azure DevOps (per environment `<env>` = dev-uks, uat-uks, prod-uks)

| Thing                         | Name                          | Used for                                       |
| ----------------------------- | ----------------------------- | ---------------------------------------------- |
| Service connection (workload identity federation) | `sc-operate-iac-<env>` | Azure sign-in; Terraform gets it via `ARM_USE_OIDC` |
| Environment                   | `operate-iac-<env>`           | Approvals/checks before apply (e.g. on prod)   |
| Variable group                | `operate-iac-<env>`           | Secrets; map them in via the `secrets` parameter of `templates/stages.yml` as `TF_VAR_<name>` |
| Agent pool                    | `operate-ci-runner-<env>`     | Self-hosted agents from `ci-runner` (all pipelines but platform) |

Create the three pipelines from the YAML files with the names above. The completion triggers
look pipelines up by name.

## Example only

The code has no `backend` block: `scripts/terraform.sh` adds `backend "azurerm"` through a
gitignored `backend_override.tf` and runs `init -reconfigure` before every command, with the
state location derived from the target:

| Target                         | State                                                              |
| ------------------------------ | ------------------------------------------------------------------ |
| `network prod-uks`    | `stoprtfstateproduks001` / `tfstate` / `network/terraform.tfstate` |
| `customer-data prod-uks acme`  | `stoprtfstateproduks001` / `tfstate` / `customer-data/acme/terraform.tfstate` |

So a job can only ever touch its own target's state, even on a reused self-hosted agent.
Moving from v1 means moving each state blob to its new key (or `terraform state push`) before
the first v2 run - otherwise Terraform sees an empty state and plans to recreate everything.
No lock files are committed (example only).

## Adding things

- **New environment**: add an entry under `environments` in `global/global.tfvars`, then
  `env/<environment>.tfvars` in each service.
- **New service**: copy a sibling folder, keep the four files + `env/`, and name it for what
  it does (`customer-` / `app-services-` prefix for those tiers). Then add it to `services`
  in its pipeline file - that's what sets its tier and apply order.
- **New customer**: add `env/<environment>/<customer>.tfvars` in each `customer-*` service.
