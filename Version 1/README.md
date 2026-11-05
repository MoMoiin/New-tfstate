# operate-iac - plain Terraform layout (example, UK South: dev / uat / prod)

```
global/
  global.tfvars                  # THE one global file: `global` + every entry of `environments`

hub/                             # stack = group of services
  networking/                    # service = providers.tf variables.tf main.tf outputs.tf + own state
    env/dev-uks.tfvars           #   file name = environment; holds only this service's values
    env/uat-uks.tfvars           #   (file must exist - even empty - for the service to run there)
    env/prod-uks.tfvars
  key-vault/  dns/  domain-controller/  ci-runner/  image-gallery/  monitoring/
shared/
  networking/  key-vault/  storage/  sql/  app-gateway/
  app-cluster/  prizm/  seq/  dns/  monitoring/
client/                          # one state per (customer, service)
  networking/  app/  data/
    env/<environment>/acme.tfvars  # folder = environment, file name = customer
app-services/
  networking/  app-service/

modules/                         # reusable building blocks (no provider/backend)
scripts/
  terraform.sh                   # runs any service: picks the tfvars by name, passes the rest
  bootstrap/                     # initialize-subscription.ps1, register-ci-runner-agent.ps1
  lib/                           # dot-sourced by operators/pipelines (az login)
  vm/windows, vm/linux           # runs ON the VM (IMDS only)
```

## How a service gets its values

Terraform only ever runs in the pipeline - nobody runs it by hand. Each pipeline job runs one
service for one environment (and customer) through `scripts/terraform.sh`:

```bash
scripts/terraform.sh hub/networking prod-uks plan
scripts/terraform.sh client/data prod-uks acme plan
```

which runs, for example:

```bash
terraform -chdir=client/data plan \
  -var-file=<repo>/global/global.tfvars \
  -var-file=env/prod-uks/acme.tfvars \
  -var environment=prod-uks -var customer=acme
```

- **The tfvars file name is the environment** (and, under `client/`, the customer). The file
  never repeats it - the script passes `-var environment=` / `-var customer=` from the same
  name it picked the file by, so the two can't disagree. No file = the service isn't enabled
  there, and the script refuses to run.
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
seq, prizm and app-cluster each write their A record into the hub's `operate.internal` zone.

## Where does a value go?

- Same for every service and environment -> `global` in `global/global.tfvars`
- Same for every service in one environment -> that entry of `environments` in `global/global.tfvars`
- Specific to one service -> `<stack>/<service>/env/<environment>.tfvars`
- Created by another service -> look it up by name with a `data` source

## Apply order

1. hub: networking -> domain-controller, dns, key-vault, ci-runner, image-gallery, monitoring
2. shared: networking, sql -> key-vault, storage, app-gateway, app-cluster, prizm, seq, dns, monitoring
3. app-services: networking -> app-service
4. client (per customer): networking -> data -> app

## Example only

The code has no `backend` block: `scripts/terraform.sh` adds `backend "azurerm"` through a
gitignored `backend_override.tf` and runs `init -reconfigure` before every command, with the
state location derived from the target:

| Target                     | State                                                                 |
| -------------------------- | --------------------------------------------------------------------- |
| `hub/networking prod-uks`  | `stoprtfstateproduks001` / `hubtfstate` / `hub/networking/terraform.tfstate` |
| `client/data prod-uks acme`| `stoprtfstateproduks001` / `clienttfstate` / `client/acme/data/terraform.tfstate` |

So a job can only ever touch its own target's state, even on a reused self-hosted agent.
No lock files are committed (example only).

## Adding things

- **New environment**: add an entry under `environments` in `global/global.tfvars`, then
  `env/<environment>.tfvars` in each service.
- **New service**: copy a sibling folder and keep the four files + `env/`.
- **New customer**: add `env/<environment>/<customer>.tfvars` in each `client/<service>`.
