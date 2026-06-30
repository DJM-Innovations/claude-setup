# Always Use Latest Package Versions

When adding dependencies to `package.json`, always check the latest version first:

```bash
npm view <package-name> version
```

Then use that exact latest version with a caret prefix (`^`).

## Never

- Use outdated versions when creating new packages
- Copy version numbers from other packages in the monorepo without checking latest
- Use approximate versions like `"^2.0.0"` when `"^2.8.0"` is current

## Exception

When a package must match an existing version in the monorepo for compatibility (e.g., `viem` pinned across packages), match the monorepo version instead.
