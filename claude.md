# Initial instructions
* Provide the direct answer or code block only. Strictly skip all commentary, intros, explanations, and conversational filler."

# Vivado FPGA Project — Claude Instructions

## Role & Tools

This is an AMD/Xilinx Vivado FPGA project.

* Use **Terminal** for RTL, files, Tcl, XDC, simulation, scripts, and Git.
* Use **`vivado` MCP** for Vivado/project state, synthesis, implementation, timing, DRC, CDC, utilization, and reports.
* Never guess Vivado state when MCP can inspect it.
* Do not invent MCP tools or parameters; inspect available tools when needed.
* Report actual MCP errors; never assume success.

## Vivado Environment

Vivado 2025.2:

```bash
source /tools/Xilinx/2025.2/Vivado/settings64.sh
```

Project:

```text
./Projects/db6v5_vivado_2025_2/db6v5_vivado_2025_2.xpr
```

If Xilinx tools are unavailable, source the environment. Do not source it repeatedly when already configured.

## File Scope

**Inspect by default only:**

* `.v`, `.sv`, `.vhd`
* `.xdc`
* Tcl/scripts
* project/configuration files
* README/documentation
* files relevant to the user's request
* Git status/diffs

**Do NOT explore recursively by default:**

```text
*.runs/
*.cache/
*.gen/
*.hw/
*.ip_user_files/
*.sim/
impl/
synth/
.Xil/
generated IP
generated reports
large logs
```

Avoid broad commands such as:

```bash
find . -type f
```

Do not dump entire logs or reports into context.

### Escalation

Inspect generated files **only when**:

* an error/critical warning points to them;
* timing/DRC/CDC requires information unavailable through MCP;
* the user explicitly requests it; or
* MCP cannot provide the required information.

When escalating, inspect only the specific relevant file/report/path.

## Warnings & Context

Keep context small.

Prioritize:

1. Errors
2. Critical warnings
3. Timing violations
4. DRC violations
5. CDC violations
6. Warnings related to the current task

Ignore unrelated informational messages and ordinary warnings unless they become relevant.

Summarize repeated warnings with counts/examples. Do not repeatedly report the same issue.

Prefer MCP summaries over manually reading generated logs.

For timing, focus on **WNS, TNS, failing endpoints, worst setup/hold paths**.

## Workflow

1. Understand the request.
2. Inspect only relevant source/configuration files.
3. Check `git status`.
4. Query relevant Vivado state through MCP.
5. Make the smallest appropriate change.
6. Verify the change.
7. Review only errors, critical warnings, violations, and task-relevant warnings.
8. Escalate into generated files only when necessary.

## RTL & Constraints

When modifying RTL, consider:

* clocks/clock domains and CDC
* resets
* widths and signedness
* pipeline latency
* handshakes/throughput
* synthesizability

Preserve existing interfaces and behavior unless explicitly asked otherwise.

Do not guess pins, clocks, IO standards, or timing constraints. Inspect existing XDC/Vivado state first.

Never hide timing problems blindly with:

```text
set_false_path
set_multicycle_path
relaxed constraints
```

Determine the actual cause first and check both setup and hold.

## IP & Generated Files

Do not manually modify generated Vivado/IP files when the underlying RTL, Tcl, XDC, or IP configuration can be changed instead.

Do not upgrade or regenerate IP without understanding the consequences.

## Verification

Verify significant changes with the appropriate checks:

* Elaboration
* Simulation
* Synthesis
* Implementation
* Timing
* CDC
* DRC

Never claim something is fixed or working unless it was actually verified.

## Git

Before changes:

```bash
git status
```

After changes:

```bash
git diff
```

Do not commit or use destructive Git commands unless explicitly requested.

## Debugging

When something fails:

1. Get the actual error.
2. Identify the affected module/signal/path/clock.
3. Determine the root cause.
4. Make the smallest appropriate change.
5. Verify again.

Do not make unrelated changes merely to suppress an error.

## Communication

For significant changes, briefly state:

* **What changed**
* **Why**
* **What was verified**
* **Remaining errors/warnings/issues**

If something was not verified, say so explicitly.

## Core Principle

**Explore narrowly. Use Vivado MCP first. Keep generated files out of context unless necessary. Focus on actionable problems. Make small changes. Never guess. Always verify.**
