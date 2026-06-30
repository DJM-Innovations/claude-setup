---
name: prompt-engineering
description: Use when writing or reviewing LLM prompts for production agents (system prompts, intent classifiers, response generators, structured-output schemas). Trims bloat, removes brittle hardcoded examples, eliminates anti-patterns like ticket references and ALL-CAPS NEGATIVES, and produces concise, schema-shaped, model-friendly prompts.
---

# Prompt Engineering — Production LLM Prompts

A prompt is API surface. It runs millions of times, gets paged in fresh on every call, and the model only sees what's there. Treat it like code: tight, intentional, no dead lines.

## When to use

- You're authoring or editing a system prompt, intent-classification prompt, structured-output prompt, or response-shaping prompt that ships to production.
- A reviewer (or you) feels the prompt is "bloated", "brittle", or "weird".
- Symptoms: model ignores rules, prompt is >300 lines, reviewers say "this is hard to read", behaviour breaks when one example is rephrased, prompt mentions specific tickets or pull requests.

## The 10 rules

1. **Lead with role + goal in one sentence, then the input shape, then the output shape.** Everything else is supporting detail.
2. **Tell the model what to DO, not a wall of NOT.** Replace each "NEVER do X" with the positive form. One genuine constraint per concept.
3. **Never reference Jira tickets, PR numbers, or commit SHAs in a prompt.** The LLM can't fetch them, they rot, they leak internal context. Inline the actual rule the ticket described.
4. **No ALL CAPS, no ❗❗, no triple-exclamation marks.** They don't increase compliance — they signal the author distrusts the model and crowd out content.
5. **Generalize over enumerate.** "Any topic shift breaks sticky intent" beats `"Profit Leaks", "Sales Today", "Labor Today"`. Enumerated lists overfit and silently fail on the next variant.
6. **Use schema + few-shot, not paragraphs of rules.** If output is structured, define the schema (Zod, JSON-schema). Add 1–3 *diverse* few-shot pairs. Don't write 30 inline examples.
7. **Show the desired voice with one short example, not five negative examples.** Negative examples train the model on the bad pattern.
8. **Variables go in `{braces}`, not narrative.** Don't write "the user's question follows" — put `USER QUESTION: {question}` and let template substitution be the only delimiter.
9. **One closing instruction.** End with the actual task ("Respond.", "Return JSON.", "Classify."). Avoid trailing meta like "Be helpful and accurate".
10. **Audit by deletion.** Read each line and ask: *if I delete this, does the model do something different?* If no, delete. A 60-line prompt usually compresses to 25.

## Anti-patterns checklist

Reject the prompt if you see:

- [ ] References to internal tickets / PRs / SHAs / external URLs the LLM can't fetch
- [ ] More than ~5 lines of "NEVER do X" rules
- [ ] An enumerated list of phrases the model is supposed to memorize (>5 items)
- [ ] Multiple sections that reformulate the same rule
- [ ] Inline JSON examples longer than the schema itself
- [ ] Markdown headers (#, ##) in user-facing output instructions when the response will be rendered as plain text in chat
- [ ] Trailing motivational text ("Be confident", "Be supportive", "Always be helpful")
- [ ] Direct quotes of expected user wording (these overfit to the QA test)
- [ ] Conversational filler in instructions ("now then", "as you know", "remember to")

## Skeleton — system prompt

```
You are <role>. <one-sentence goal>.

INPUT
- {field1}: <what it is>
- {field2}: <what it is>

OUTPUT
<one paragraph or schema describing the shape>

RULES
- <rule 1, positive form>
- <rule 2, positive form>
- <rule 3 — only if it materially changes behavior>

EXAMPLE  (optional, only if behavior is hard to specify in prose)
INPUT: ...
OUTPUT: ...

Respond.
```

That's the whole template. If your prompt has more than 3 rules, ask whether two of them are saying the same thing.

## Skeleton — intent / classifier prompt with structured output

For classifiers, lean on the schema (Zod / JSON-schema) — the schema enforces shape, the prompt only needs to describe semantics:

```
Classify the user's message into the schema below.

CONTEXT
- Now: {currentDateTime}
- Conversation so far: {conversationHistory}

CURRENT MESSAGE
{message}

GUIDANCE
- <one line per category that's hard to disambiguate>
- Sticky intent applies only when the user replies with a short continuation token ("yes", "no", "next", "1"). Any other input — including a new topic name — is classified on its own merit.

Return the JSON.
```

Notice: no "NEVER", no enumerated examples of every Quick-Ask topic, no ticket references. The model is good at recognizing topic shifts; spell out the *principle* once.

## Voice rules for response-generation prompts

If the prompt produces user-visible chat text:

- Specify person/voice in one line ("Speak directly to the manager in second person.").
- Specify length envelope ("2–4 sentences" or "one short paragraph per entry").
- Specify what variables MUST be quoted from the data (so the model doesn't hallucinate numbers).
- Trust the model on tone — don't over-prescribe register beyond "conversational" or "professional".

Example — bad:

> ABSOLUTE RULES — DO NOT VIOLATE: NEVER write the phrase "Marty might say" anywhere. Speak directly as Marty in first-person. Never use markdown headers. NEVER fabricate sales numbers. ABSOLUTE RULES …

Example — good:

> Speak directly to the manager in second person. Quote each figure from the log data verbatim — do not invent values. Open each entry with the operator's name and the date. Plain prose, no markdown headers.

Same constraints, half the tokens, no negative-pattern training.

## Reviewing an existing prompt

When asked to review or fix a prompt, do this in order:

1. **Read end-to-end once.** Don't edit yet.
2. **Strip dead weight.** Pass through: delete ticket refs, ALL-CAPS warnings, duplicate rules, motivational filler, contradictory instructions.
3. **Collapse enumerations.** "Profit Leaks / Sales Today / Labor Today" → "any new topic name".
4. **Move format to schema.** If the response shape is structured, push field rules into the Zod schema, not the prompt.
5. **Add a single example only if behavior is genuinely hard to describe.**
6. **Read aloud.** If a sentence sounds like the author was angry at the model, rewrite it.
7. **Diff token count.** A clean rewrite usually drops 40–60% of tokens with equal or better behaviour.

## Verifying behavior didn't regress

After a prompt refactor:

- Run the original failing case the prompt was written for.
- Run 3–5 cases that previously passed.
- Run 2 adversarial cases (typos, off-topic, multi-intent).
- Spot-check token usage — if input length dropped meaningfully, latency and cost improve.

If any pre-existing case now fails, the deleted rule was real — restore the *principle* (not the verbatim sentence).
