# Initial instructions
* Provide the direct answer or code block only. Skip commentary, intros, explanations, and filler.

# Vivado FPGA Project — Claude Instructions

## Environment
AMD/Xilinx Vivado 2025.2.

Vivado setup:
source /tools/Xilinx/2025.2/Vivado/settings64.sh

Project:
./Projects/db6v5_vivado_2025_2/db6v5_vivado_2025_2.xpr

Use:
- Terminal: RTL, files, Tcl, XDC, simulation, scripts, Git
- vivado MCP: project/Vivado state, synthesis, implementation, timing, DRC, CDC, utilization, reports

Never guess Vivado state when MCP can inspect it. Never invent MCP tools/parameters; inspect available tools when needed. Report actual MCP errors.

## Scope
Inspect only files relevant to the request and the instantiated top-level file tree.

Normally inspect:
- .v, .sv, .vhd
- .xdc
- Tcl/scripts
- project/config files
- README/docs relevant to the task
- Git status/diffs

Do not recursively explore generated/build data:
*.runs/ *.cache/ *.gen/ *.hw/ *.ip_user_files/ *.sim/
impl/ synth/ .Xil/ generated IP/reports/large logs

Avoid broad commands such as:
find . -type f

Inspect generated files/reports only when:
- an error/critical warning references them
- MCP lacks required timing/DRC/CDC information
- explicitly requested
- required to diagnose the current issue

Inspect only the specific relevant path/report. Do not dump large logs/reports into context.

## Priority
Prioritize:
1. Errors
2. Critical warnings
3. Timing violations
4. DRC violations
5. CDC violations
6. Task-relevant warnings

Ignore unrelated informational output and ordinary warnings unless relevant. Summarize repeated warnings with counts/examples.

For timing, focus on WNS, TNS, worst setup/hold paths, and failing endpoints.

## Workflow
1. Understand the request.
2. Inspect relevant source/configuration.
3. Check git status.
4. Query relevant Vivado state via MCP.
5. Make the smallest appropriate change.
6. Verify the change.
7. Review errors, critical warnings, violations, and task-relevant warnings.
8. Escalate to generated files only if necessary.

## RTL/Constraints
When changing RTL, check:
- clocks/CDC
- resets
- widths/signedness
- pipeline latency
- handshakes/throughput
- synthesizability

Preserve existing interfaces and behavior unless explicitly requested otherwise.

Never guess pins, clocks, IO standards, or timing constraints. Inspect existing XDC/Vivado state first.

Do not hide timing problems with false paths, multicycle paths, or relaxed constraints without first determining the real cause. Check both setup and hold.

## IP/Generated Files
Do not manually edit generated Vivado/IP files when the underlying RTL, Tcl, XDC, or IP configuration can be changed instead.

Do not upgrade or regenerate IP without understanding the consequences.

## Verification
For significant changes, run the checks appropriate to the change:
- elaboration
- simulation
- synthesis
- implementation
- timing
- CDC
- DRC

Never claim a fix or successful operation without actual verification. Explicitly state anything not verified.

## Git
Before changes:
git status

After changes:
git diff

Do not commit or use destructive Git commands unless explicitly requested.

## Debugging
For failures:
1. Obtain the actual error.
2. Identify affected module/signal/path/clock.
3. Determine root cause.
4. Make the smallest fix.
5. Verify again.

Do not make unrelated changes to suppress errors.

## Communication
For significant changes, report only:
- What changed
- Why
- What was verified
- Remaining errors/warnings/issues

## Core Principle
Explore narrowly. Prefer Vivado MCP for Vivado state. Keep generated files out of context. Make minimal changes. Never guess. Always verify.