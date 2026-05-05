# Workflows

## Workflow 1 - Re-enter through Goal Forest

- actor: user
- trigger: open the app and regain orientation
- normal flow: open Goal Forest -> inspect relevant node/context -> open or resume a work session -> continue work with Goal Forest as supporting context
- exception flow: if the right context is unclear, use recent session or capture first and link later
- observable outcome: the user regains orientation without a generic dashboard

## Workflow 2 - Continue active work through a work session

- actor: user
- trigger: there is an active or recent work session
- normal flow: resume the session directly -> see continuity and linked tools -> continue without full-forest browsing
- exception flow: if broader context is needed, open Goal Forest from the session
- observable outcome: the session remains the primary execution surface

## Workflow 3 - Quick capture without classification tax

- actor: user
- trigger: something worth saving appears while the user is anywhere in the app
- normal flow: use global capture affordance -> record the item -> optionally attach to a session or Goal Forest node -> save
- exception flow: if placement is unclear, save without classifying and return later
- observable outcome: important state is saved without heavy interruption

## Workflow 4 - Session-linked remote execution

- actor: user
- trigger: remote work is needed from inside a work session
- normal flow: open Remote Control from the session -> connect to a saved host -> do terminal/file work -> leave a small continuity bundle in the session
- exception flow: if no host is configured yet, create or select a host profile before continuing
- observable outcome: remote work stays inside the broader crafting table loop

## Workflow 5 - Remote first, session second

- actor: user
- trigger: the user enters Remote Control directly for quick action
- normal flow: open Remote Control -> connect to a host -> attach to a current, recent, or new session -> preserve continuity
- exception flow: if the user leaves before attaching, the unattached state must remain visible and recoverable
- observable outcome: quick remote action stays cheap without becoming orphaned product state

## Workflow 6 - Start a local model server

- actor: user
- trigger: the user wants nearby tools or local chat to use an open-source model hosted on the iPad
- normal flow: open Local LLM -> add or choose a GGUF model -> download and verify it -> activate it -> reveal or copy the bearer token -> start the HTTP server -> call the displayed URL from a trusted LAN client
- exception flow: if no model is ready, the app keeps server and model readiness visible and lets the user complete the model lifecycle first
- observable outcome: local model serving is deliberate, authenticated, and visible while the app stays foregrounded
