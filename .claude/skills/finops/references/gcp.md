# Google Cloud cost checklist (including Firebase)

Prices and free tiers change. Look them up in the current docs or the user's billing data;
do not quote from memory. Use read-only commands, and only if `gcloud` is authenticated.

## Data (read-only)
```bash
gcloud billing budgets list --billing-account=<ID>
gcloud run services list --format="table(metadata.name,status.url,spec.template.spec.containerConcurrency)"
gcloud run services describe <svc> --region <r> --format=yaml          # min/max instances, cpu, memory
gcloud compute instances list --format="table(name,zone,machineType.basename(),status)"
gcloud compute disks list --filter="-users:*"                           # unattached disks
gcloud compute addresses list --filter="status:RESERVED"                # unused static IPs
gcloud artifacts docker images list <repo-path> --include-tags
gcloud logging sinks list ; gcloud logging buckets list                 # where logs go, retention
```
Best source: Cloud Billing export to BigQuery, grouped by service, SKU, project and label.
Also Active Assist / Recommender in the console. Ask the user for a billing export if you lack access.

## Findings to look for
| Service | Waste | Fix | Careful |
|---|---|---|---|
| Cloud Run | `min-instances` > 0 on idle or non-critical services | 0, or lower | cold starts: keep warm where latency matters |
| Cloud Run | CPU always allocated for request-driven work | request-based CPU allocation | background work needs always-on |
| Cloud Run | oversized CPU/memory, low concurrency | right-size from metrics, raise concurrency | load test first |
| Cloud Run | no `max-instances` | cap as a cost guard | do not cap below peak traffic |
| Firestore | listeners (`onSnapshot`) on large collections, repeated reads, N+1 | targeted queries, `limit`, pagination, field `select`, cache, listen to documents not collections | every read is billed |
| Firestore | counting by reading docs | `count()` aggregation | |
| Firestore | old data kept forever, unused composite indexes | TTL policies, remove unused indexes | indexes cost storage and writes |
| Realtime Database | root-level listeners, large payloads, stale nodes | narrow listeners, prune, move bulky data | bandwidth and storage are billed |
| Cloud Logging | debug logs in production, request logs for health checks | log levels, exclusion filters, sampling, shorter retention | keep audit and security logs |
| Artifact Registry | every old image kept | cleanup policies (keep last N and tagged) | keep what rollback needs |
| Cloud Storage | no lifecycle, versioning bloat, wrong class or location | lifecycle rules, right class, regional over multi-region where allowed | retention obligations |
| Compute Engine | idle or oversized VMs, unattached disks, unused static IPs, old snapshots | right-size, delete orphans, snapshot schedule with retention | **SIP/PBX hosts need headroom and redundancy; never cut a node of an HA pair** |
| Compute Engine | steady baseline on on-demand pricing | committed use discounts after 2-3 stable months | not for spiky or uncertain load |
| Networking | egress, especially RTP media and cross-region traffic | co-locate components, check path and region | check media routing before moving anything |
| Cloud Build / CI on GCP | big machine type, no cache | right-size, layer caching | |
| Secret Manager | many old versions, high-frequency access | destroy unused versions, cache secrets in the process | |
| Everything | no budgets, no labels | budgets with alerts (for example 50/90/100%), labels per service and environment | |

## Implementation patterns that cost money
- Unbounded queries, missing pagination, repeated identical reads inside a request or loop.
- Polling where an event or webhook exists; retry loops without backoff or a cap.
- Cron jobs more frequent than the data changes; webhook handlers that do the work twice.
- Debug or per-request logging left on in production; logging whole payloads.
- Large container images, dev dependencies in the runtime image, rebuilding what has not changed.
- Writing a document per event when batching would do (for example CDR or live-call state).

## Judging a finding
- Tie it to a billing line or a metric when you can, and say when you cannot.
- Prefer config-only changes (limits, retention, filters) before code changes.
- If a saving touches production behavior, list the verification and the rollback.
