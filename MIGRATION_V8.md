# Migrating from v7 (Procedural) to v8 (Orchestrated)

PrinterToolkit v8 keeps every v7 capability intact but refactors the internal
execution model. This guide is for maintainers extending the toolkit.

## What changed

| Concern            | v7                                              | v8                                                          |
|--------------------|-------------------------------------------------|-------------------------------------------------------------|
| Execution          | Procedural helper chains (`Invoke-ZT*`)         | Declarative task graph executed by `Invoke-Orchestrator`    |
| Ordering           | Hard-coded call sequence                         | Topological DAG (`Get-TopologicalTaskOrder`, cycle-checked)  |
| State awareness    | Ad-hoc checks                                   | State Manager (`Set/Get-SubsystemState`)                    |
| Observability      | Log lines only                                  | Event Bus (`Subscribe/Publish-OrchestrationEvent`)          |
| Audit              | Per-deployment transaction log                  | Per-task transactions (`Record-TaskTransaction`)            |
| Rollback / recovery| Manual rollback after full failure              | Automatic retry → rollback → recovery per task             |

`Start-ZeroTouchDeployment` remains backward compatible: same parameters
(`-PrinterName`, `-ShareName`, `-SkipValidation`) and same return object
(`Success`, `TransactionId`, `PrinterName`, `Detected`, `Configuration`,
`Validation`, `Health`, `RollbackPerformed`, `Errors`). Internally it now
builds an `OrchestrationTask[]` DAG and calls `Invoke-Orchestrator`.

## Adding a new operation

Prefer expressing new behavior as a **Task** rather than a new procedural
function:

```powershell
$task = New-OrchestrationTask -Name 'ConfigureFoo' -Description '...' `
    -Category 'Configuration' -Subsystem 'Foo' -RequiredElevation $true `
    -Dependencies @('ConfigureServices') `
    -RetryPolicy @{ MaxAttempts = 2; DelayMs = 500 } `
    -Execute  { Invoke-ConfigurationProvider -Provider 'Foo' -Phase ApplyChanges -DesiredState $desired } `
    -Validate { Invoke-ConfigurationProvider -Provider 'Foo' -Phase Validate -DesiredState $desired }
```

If the operation is a brand-new platform area, add a branch to the
`switch ($Provider)` in `Invoke-ConfigurationProvider` implementing the
phases: `GetCurrentState`, `GetDesiredState`, `PlanChanges`,
`ApplyChanges`, `Validate`, `Rollback`. Reuse existing module functions
(e.g. `Set-ServiceConfiguration`, `Enable-PrinterSharing`) — do not
duplicate Windows logic inside the provider.

## Rules

- Tasks must **not** call each other's `Execute`/`Validate` directly. The
  orchestrator resolves the order from `Dependencies`.
- `RequiredElevation` is enforced automatically; the orchestrator skips
  non-elevated tasks that require elevation and cascades the skip to dependents.
- `IsCritical = $false` / `CanSkip = $true` tasks never fail the whole run.
- Keep platform specifics inside the existing modules; the Orchestration
  module orchestrates, it does not own Windows configuration logic.
