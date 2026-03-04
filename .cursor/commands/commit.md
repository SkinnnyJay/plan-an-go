# Commit Changes (plan-an-go)

Group changes into logical, atomic commits. Use conventional commits.

## Steps

1. **Review**: `git status` and `git diff --staged`.
2. **Plan**: Group into logical commits. Format: `<type>(<scope>): <summary>` — types: feat, fix, chore, refactor, docs, test. Present tense, imperative, under 72 chars.
3. **Quality gate**: Run `npm run check` before committing.
4. **Commit**: Stage each group and commit separately.
5. **Never commit**: `.env`, credentials, or secrets.

## Checklist

- [ ] Commits atomic and logically grouped
- [ ] Message format: feat:, fix:, docs:, etc.
- [ ] `npm run check` passes; no secrets in commit
