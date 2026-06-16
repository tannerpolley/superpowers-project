# Native Q&A Main Flow Mermaid

This is the simplified Mermaid companion to `native-qa-main-flow.svg`. It shows only the top-level native Q&A gates. Nested route menus stay inside their owning skill boxes unless the route chooses between actual workflow skills.

```mermaid
%%{init: {"flowchart": {"curve": "linear"}, "theme": "base", "themeVariables": {"background": "#ffffff", "primaryTextColor": "#111827", "lineColor": "#111827", "fontFamily": "Arial"}}}%%
flowchart TB
    start(["Start"])
    rule["First-level gate rule<br/>Continue? = Yes / Revisit / Stop<br/>Stop means pause. Done means complete."]
    initiate["Initiate Workflow<br/>Ask project_workflow_mode before task routing"]
    mode_gate{"project_workflow_mode<br/>Manual Mode / Auto Mode / Looping Mode"}
    mode_manual["Manual Mode<br/>ask at each material decision"]
    mode_auto["Auto Mode<br/>one-route autonomy only"]
    loop_controller["Loop Controller<br/>Looping Mode selects one maintenance candidate, routes to the owning skill, and repeats by budget"]
    d_initiate{"Continue?<br/>from router<br/>Yes / Revisit / Stop"}
    revisit_initiate["Revisit Route<br/>review routing and choose another entry"]
    stop_initiate["Stop"]

    setup["Setup Project<br/>Nested routes: roadmap, milestones, tracker, GitHub Project board, align"]
    d_setup{"Continue?<br/>from setup<br/>Yes / Revisit / Stop"}
    revisit_setup["Revisit Setup<br/>repair roadmap, tracker, board, or context"]
    stop_setup["Stop"]

    brainstorm["Brainstorm Spec<br/>Nested routes: manual planning, write plan, revise spec"]
    d_brainstorm{"Continue?<br/>from brainstorm<br/>Yes / Revisit / Stop"}
    revisit_brainstorm["Revisit Spec<br/>review assumptions, grill, or revise scope"]
    stop_brainstorm["Stop"]

    d_spec_or_audit{"Choose spec route?<br/>new direction or existing findings"}
    audit_project["Audit Project<br/>Review existing code/workflows and write P-coded findings spec"]
    d_audit_project{"Continue?<br/>from audit findings<br/>Yes / Revisit / Stop"}
    revisit_audit["Revisit Audit<br/>review findings, gather evidence, or rerun focused audit"]
    stop_audit_project["Stop"]

    plan["Write Plan<br/>Nested revisit routes: review, grill, rescope"]
    d_plan{"Continue?<br/>from plan<br/>Yes / Revisit / Stop"}
    revisit_plan["Revisit Plan<br/>review, grill, rescope, or revise tasks"]
    stop_plan["Stop"]
    d_work_route{"Choose work route?<br/>select the next blue skill"}

    implement["Implement Plan<br/>Non-issue branch with /goal, tests, verification, and merge proof"]
    create_issues["Create Issues<br/>Publish GitHub issues and sync local issue mirrors"]

    d_implement{"Continue?<br/>from implementation<br/>Yes / Revisit / Stop"}
    revisit_implement["Revisit Branch<br/>review evidence, revise branch, or rerun proof"]
    stop_implement["Stop"]

    d_create{"Continue?<br/>from issues<br/>Yes / Revisit / Stop"}
    revisit_create["Revisit Issues<br/>repair mirrors, labels, or issue slices"]
    stop_create["Stop"]
    d_issue_route{"Choose issue route?<br/>select the next blue skill"}

    orchestrate["Orchestrate Issues<br/>Worker worktree route with aligned thread, branch, and PR handoff"]
    resolve["Resolve Issue<br/>Current thread uses /goal, TDD, verification, branch, and PR"]

    d_ready{"Continue?<br/>from resolved work<br/>Yes / Revisit / Stop"}
    revisit_ready["Revisit Output<br/>review PR-ready proof, CI, or worker handoff"]
    stop_ready["Stop"]

    merge["Merge Changes<br/>Approval, checks, merge, issue close, branch/worktree cleanup"]
    d_merge{"Continue?<br/>from merge<br/>Yes / Revisit / Stop"}
    revisit_merge["Revisit Merge<br/>review checks, cleanup, or closeout proof"]
    stop_merge["Stop"]

    align["Align Project<br/>Optional alignment check for drift, sync, trackers, and artifacts"]
    d_align{"Continue?<br/>from alignment<br/>Yes / Revisit / Stop"}
    align_repair["Repair Route<br/>apply repair or prepare planning work"]
    revisit_align["Revisit Align<br/>repair drift and run Align again"]
    stop_align["Stop"]

    subgraph gate_initiate[" "]
        direction LR
        revisit_initiate ~~~ d_initiate ~~~ stop_initiate
    end

    subgraph mode_choices[" "]
        direction LR
        mode_manual ~~~ mode_gate ~~~ mode_auto ~~~ loop_controller
    end

    subgraph gate_setup[" "]
        direction LR
        revisit_setup ~~~ d_setup ~~~ stop_setup
    end

    subgraph gate_brainstorm[" "]
        direction LR
        revisit_brainstorm ~~~ d_brainstorm ~~~ stop_brainstorm
    end

    subgraph spec_choices[" "]
        direction LR
        brainstorm ~~~ d_spec_or_audit ~~~ audit_project
    end

    subgraph gate_audit_project[" "]
        direction LR
        revisit_audit ~~~ d_audit_project ~~~ stop_audit_project
    end

    subgraph gate_plan[" "]
        direction LR
        revisit_plan ~~~ d_plan ~~~ stop_plan
    end

    subgraph work_choices[" "]
        direction LR
        implement ~~~ d_work_route ~~~ create_issues
    end

    subgraph gate_implement[" "]
        direction LR
        revisit_implement ~~~ d_implement ~~~ stop_implement
    end

    subgraph gate_create[" "]
        direction LR
        revisit_create ~~~ d_create ~~~ stop_create
    end

    subgraph issue_choices[" "]
        direction LR
        orchestrate ~~~ d_issue_route ~~~ resolve
    end

    subgraph gate_ready[" "]
        direction LR
        revisit_ready ~~~ d_ready ~~~ stop_ready
    end

    subgraph gate_merge[" "]
        direction LR
        revisit_merge ~~~ d_merge ~~~ stop_merge
    end

    subgraph gate_align[" "]
        direction LR
        revisit_align ~~~ d_align ~~~ stop_align
    end

    start --> rule --> initiate --> mode_gate
    mode_gate -->|Manual Mode| mode_manual --> d_initiate
    mode_gate -->|Auto Mode| mode_auto --> d_initiate
    mode_gate -->|Looping Mode| loop_controller --> d_initiate
    d_initiate -->|Yes| setup
    d_initiate -->|Revisit| revisit_initiate --> initiate
    d_initiate -->|Stop| stop_initiate

    setup --> d_setup
    d_setup -->|Yes| d_spec_or_audit
    d_setup -->|Revisit| revisit_setup --> setup
    d_setup -->|Stop| stop_setup

    d_spec_or_audit -->|Brainstorm Spec| brainstorm
    d_spec_or_audit -->|Audit Project| audit_project

    brainstorm --> d_brainstorm
    d_brainstorm -->|Yes| plan
    d_brainstorm -->|Revisit| revisit_brainstorm --> brainstorm
    d_brainstorm -->|Stop| stop_brainstorm

    audit_project --> d_audit_project
    d_audit_project -->|Yes| plan
    d_audit_project -->|Revisit| revisit_audit --> audit_project
    d_audit_project -->|Stop| stop_audit_project

    plan --> d_plan
    d_plan -->|Yes| d_work_route
    d_plan -->|Revisit| revisit_plan --> plan
    d_plan -->|Stop| stop_plan
    d_work_route -->|Implement Plan| implement
    d_work_route -->|Create Issues| create_issues

    implement --> d_implement
    d_implement -->|Yes| merge
    d_implement -->|Revisit| revisit_implement --> implement
    d_implement -->|Stop| stop_implement

    create_issues --> d_create
    d_create -->|Yes| d_issue_route
    d_create -->|Revisit| revisit_create --> create_issues
    d_create -->|Stop| stop_create
    d_issue_route -->|Orchestrate| orchestrate
    d_issue_route -->|Resolve| resolve

    orchestrate --> d_ready
    resolve --> d_ready
    d_ready -->|Yes| merge
    d_ready -->|Revisit| revisit_ready --> d_issue_route
    d_ready -->|Stop| stop_ready

    merge --> d_merge
    d_merge -->|Yes| align
    d_merge -->|Revisit| revisit_merge --> merge
    d_merge -->|Stop| stop_merge

    align --> d_align
    d_align -->|Yes| align_repair --> align
    d_align -->|Revisit| revisit_align --> align
    d_align -->|Stop| stop_align

    classDef start fill:#0f172a,stroke:#020617,color:#ffffff,stroke-width:2px
    classDef skill fill:#dbeafe,stroke:#2563eb,color:#111827,stroke-width:2px
    classDef decision fill:#fef3c7,stroke:#d97706,color:#111827,stroke-width:2px
    classDef revisit fill:#f3f4f6,stroke:#6b7280,color:#111827,stroke-width:2px
    classDef stop fill:#fee2e2,stroke:#dc2626,color:#991b1b,stroke-width:2px
    classDef done fill:#dcfce7,stroke:#16a34a,color:#166534,stroke-width:2px

    class start start
    class initiate,loop_controller,setup,brainstorm,audit_project,plan,implement,create_issues,orchestrate,resolve,merge,align skill
    class mode_gate,d_initiate,d_setup,d_spec_or_audit,d_brainstorm,d_audit_project,d_plan,d_work_route,d_implement,d_create,d_issue_route,d_ready,d_merge,d_align decision
    class rule,mode_manual,mode_auto,align_repair,revisit_initiate,revisit_setup,revisit_brainstorm,revisit_audit,revisit_plan,revisit_implement,revisit_create,revisit_ready,revisit_merge,revisit_align revisit
    class stop_initiate,stop_setup,stop_brainstorm,stop_audit_project,stop_plan,stop_implement,stop_create,stop_ready,stop_merge,stop_align stop

    style gate_initiate fill:transparent,stroke:transparent
    style mode_choices fill:transparent,stroke:transparent
    style gate_setup fill:transparent,stroke:transparent
    style gate_brainstorm fill:transparent,stroke:transparent
    style spec_choices fill:transparent,stroke:transparent
    style gate_audit_project fill:transparent,stroke:transparent
    style gate_plan fill:transparent,stroke:transparent
    style work_choices fill:transparent,stroke:transparent
    style gate_implement fill:transparent,stroke:transparent
    style gate_create fill:transparent,stroke:transparent
    style issue_choices fill:transparent,stroke:transparent
    style gate_ready fill:transparent,stroke:transparent
    style gate_merge fill:transparent,stroke:transparent
    style gate_align fill:transparent,stroke:transparent
```
