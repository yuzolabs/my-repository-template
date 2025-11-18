# Agent Instructions

**Think in English, output in Japanese.**

## Environment

- pnpm (always use `pnpm install --frozen-lockfile` to install dependencies)
- uv (python packages management)

## Notice

- Do not modify `package.json`/lockfiles to add or update dependencies without explicit user approval.
- Do not chain `cd` commands with `&&`.

## Tools Selection in shell

When you need to call tools from the shell, use this guide:

- Exclude bulky folders to keep searches fast and relevant: `.git`, `node_modules`, `coverage`, `out`, `dist`, `.venv`.
- Find files by file name: `fd`
- Find files with path name: `fd -p <file-path>`
- List files in a directory: `fd . <directory>`
- Find files with extension and pattern: `fd -e <extension> <pattern>`
- Find Text: `rg` (ripgrep)
- Prefer running searches against a scoped path (e.g., `src`) to implicitly avoid vendor and VCS directories.
- Examples:
  - `fd --hidden --exclude .git --exclude node_modules --exclude coverage --exclude out --exclude dist --type f ".tsx?$" src`
  - `rg -n "pattern" -g "!{.git,node_modules,coverage,out,dist}" src`
- Find Code Structure: `ast-grep`
  - Default to TypeScript when in TS/TSX repos:
    - `.ts` → `ast-grep --lang ts -p '<pattern>'`
    - `.tsx` (React) → `ast-grep --lang tsx -p '<pattern>'`
  - Other common languages:
    - Python → `ast-grep --lang python -p '<pattern>'`
    - Bash → `ast-grep --lang bash -p '<pattern>'`
    - JavaScript → `ast-grep --lang js -p '<pattern>'`
    - Rust → `ast-grep --lang rust -p '<pattern>'`
    - JSON → `ast-grep --lang json -p '<pattern>'`
  - TypeScript quick actions:
    - If `ast-grep` is available, avoid `rg` or `grep` unless a plain-text search is explicitly requested.
    - Prefer `tsx` for fast Node execution.
    - Structured search and refactors with `ast-grep`.
    - Find all exported interfaces: `ast-grep --lang ts -p 'export interface $I { ... }'`.
    - Find default exports: `ast-grep --lang ts -p 'export default $X'`.
    - Find a function call with args: `ast-grep --lang ts -p 'axios.get($URL, $$REST)'`.
    - Rename an imported specifier (codemod): `ast-grep --lang ts -p 'import { $Old as $Alias } from "$M"' --rewrite 'import { $Old } from "$M"' -U`.
    - Disallow await in Promise.all items (quick fix): `ast-grep --lang ts -p 'await $X' --inside 'Promise.all($_)' --rewrite '$X'`.
    - React hook smell: empty deps array in useEffect: `ast-grep --lang tsx -p 'useEffect($FN, [])'`.
    - List matching files then pick with fzf: `ast-grep --lang ts -p '<pattern>' -l | fzf -m | xargs -r sed -n '1,120p'`.
- JSON: `jq`
