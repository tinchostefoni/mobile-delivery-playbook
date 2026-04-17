# iOS Project Coding Standards
# Used by Gentleman Guardian Angel (GGA) as the rules file for pre-commit review.
# Customize this file to match your project's conventions.
# GGA will send staged file contents + these rules to Claude and block the commit
# if it responds with STATUS: FAILED.

## Response format (required)
You are a strict iOS code reviewer. Review the staged file(s) against the rules below.
In the first line of your response, output exactly one of:
- `STATUS: PASSED` — no violations found
- `STATUS: FAILED` — one or more violations found

Then list any violations found, referencing the specific file and line.

---

## Memory management
- Every closure that captures `self` inside a reference type MUST use `[weak self]`
  unless the type is guaranteed to outlive the closure (e.g. inside `init`).
- `guard let self = self else { return }` or `self?` MUST follow a `[weak self]` capture.
- Delegate properties MUST be declared `weak`. No retain cycles.
- `unowned` is not allowed unless lifecycle is explicitly documented with a comment.

## Force operations (hard block)
- `!` operator on optionals is PROHIBITED in production code paths.
  Exception: `IBOutlet` connections and test code only.
- `try!` is PROHIBITED. Use `try?` with a fallback or `do/catch`.
- `as!` is PROHIBITED unless inside a guarded block with explicit type verification.

## Access control
- All types, methods, and properties MUST declare explicit access control.
- `private` is preferred over `fileprivate` unless cross-type access within a file is needed.
- `public` on a type that is not part of a public API is a violation.

## Naming conventions
- Types (class, struct, enum, protocol) MUST use UpperCamelCase.
- Protocol names MUST describe capability or role: `Authenticatable`, `UserRepository`.
  Do NOT use `IUserRepository` or `UserRepositoryProtocol` prefixes/suffixes.
- No `Manager`, `Helper`, `Utils`, `Handler` suffixes unless the type genuinely manages a lifecycle.
- Methods MUST be verb phrases: `fetchUser()`, `presentLogin()`.
- Bool properties MUST start with `is`, `has`, `can`, `should`, or `will`.
- No Hungarian notation: not `strName`, `arrUsers`, `bIsLoggedIn`.
- No abbreviated parameter names: `completion` not `comp`, `animated` not `anim`.
- File name MUST match the primary type defined inside it.

## Architecture (Clean + Coordinator)
- ViewControllers MUST NOT contain business logic, network calls, or data transformations.
  These belong in UseCases or ViewModels.
- UseCases MUST NOT import UIKit.
- Repositories MUST be protocol-based; concrete implementations injected via DependencyContainer.
- Navigation MUST go through a Coordinator. No `UIViewController` pushing/presenting directly.
- Cross-module dependencies MUST go through DependencyContainer, not direct instantiation.

## Swift idioms
- Prefer `guard let` over nested `if let`.
- Prefer `compactMap`, `map`, `filter` over imperative loops when semantics are clear.
- Enum cases MUST use lowerCamelCase: `.success`, `.networkError`.
- Avoid `NSObject` subclassing when a pure Swift type suffices.
- No commented-out code blocks in production files.

## Commit hygiene
- No `print()`, `debugPrint()`, or `NSLog()` statements in production code paths.
  Use the project's logging abstraction if available.
- No `TODO:` or `FIXME:` comments introduced in this diff unless they reference an issue key.
