Analyze the contents of the provided folder and produce a generic software architectural logical model of the system.

Goal:
Create a concise architecture summary that can later be used as input to generate a diagram. The model must stay high signal, generic, and no more than 3 levels deep.

Scope:
- Infer architecture only from the folder contents.
- Use evidence from file names, directory structure, configs, manifests, code organization, docs, and infrastructure files.
- Do not invent components that are not reasonably supported by the contents.
- If something is uncertain, mark it as "inferred" or "unknown".

Instructions:
1. Identify the system’s major capabilities and organize them into two categories:
   - Logical: business/application capabilities, services, domains, workflows, interfaces, data responsibilities.
   - Physical: deployable/runtime/infrastructure elements such as apps, services, containers, databases, queues, cloud resources, external integrations, CI/CD, and environments.
2. Keep the model generic and technology-aware, but not implementation-heavy.
3. Limit hierarchy depth to 3 levels total.
   - Level 1: category
   - Level 2: capability/group
   - Level 3: sub-capability/component
4. Prefer architectural abstractions over file-by-file summaries.
5. Consolidate low-level details into broader capabilities.
6. Highlight relationships between logical and physical elements where clear.
7. If the repo contains multiple systems, represent them as separate top-level groups under the same model.
8. Include only the most important components needed to understand the architecture.

Output format:
Return the result in valid YAML using exactly this structure:

architecture_model:
  system_name: "<inferred system name>"
  summary: "<2-5 sentence architectural summary>"
  confidence: "<high|medium|low>"

  logical:
    - name: "<logical capability>"
      description: "<what it does>"
      children:
        - name: "<sub-capability>"
          description: "<what it does>"
        - name: "<sub-capability>"
          description: "<what it does>"

  physical:
    - name: "<physical element or deployment grouping>"
      description: "<what it is>"
      children:
        - name: "<contained component>"
          description: "<what it is>"
        - name: "<contained component>"
          description: "<what it is>"

  relationships:
    - from: "<logical or physical item>"
      to: "<logical or physical item>"
      type: "<depends_on|uses|stores_in|exposes|deployed_as|integrates_with|triggers>"
      description: "<short explanation>"

  evidence:
    - path: "<file or folder path>"
      reason: "<why it supports the model>"

  assumptions:
    - "<assumption or inference>"

  omissions:
    - "<important unknowns, ambiguities, or areas intentionally collapsed>"

Quality bar:
- Be concise.
- Do not exceed 3 levels of hierarchy.
- Do not dump every module, class, or file.
- Favor readability and diagram-readiness.
- Use stable, generic names such as "Web Application", "API Layer", "Data Store", "Background Processing", "Identity", "Observability", "Deployment Pipeline" when appropriate.
- If there is insufficient evidence for a category, include it only if justified and mark it as inferred.

Before producing the final YAML, think through:
- What are the main logical capabilities?
- What are the main physical/runtime elements?
- Which relationships are explicit vs inferred?
- What details should be collapsed to keep the model diagram-friendly?
