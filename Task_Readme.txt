Create plan for an in-browser app that will simulate a functioning presidential cabinet, with an LLM agent assigned to each ‘cabinet secretary’ position, and an orchestrator agent controlling tasks/timelines, almost like a presidential chief of staff.

If possible: the app should run in-browser only, no external hosting system or build dependancies, so embed all needed scripting or app subsystems in the html or other file, if possible. 

The chief of staff agent will take input in English from the human user.   This input will be a description of a task or problem to solve, and will often include links or attachments to associated data or stories.  The orchestrating agent will break down the task or problem being solved into which federal department(s) can help with a single general solution* to solve or mitigate all or part of the problem, assign the tasks to each sub-agent and wait for results, very much like a multi-agent programming project, but the agents are solving real-world resource and governing tasks.

There will be an optional ‘president’ agent which will review major national and international news (snapshot of the moment) and pick a ‘problem’ one of his departments can solve/mitigate, creates an Executive Plan and gives this to the orchestrating chief-of-staff agent.  Essentially the presidential agent is a replacement for the human in the simulation.  This can come as a later phase in the app build, or thread it in throughout if it makes a stronger build. 

I will supply open router, open and anthropic keys during the build. All of the agent models should be configurable in a ‘constants’ section in the html file, but should default to:

The department-secretary agents should be good openrouter and/or open API models
The orchestrating agent should be a higher-capability agent at openrouter or openAI, or perhaps Anthropic Sonnet 4.6
The president agent should be anthropic Opus 4.8

UI:  The running app will create very verbose levels of output and artifacts depending on the task being solved, but the UI should present the 15 secretaries and president as talking avatars with labels beneath them.  They should announce in text and optionally audibly in a well-rendered voice when their department has been given a task by the orchestrator and when the tasks completes.  The user should be able to ask questions of any of the cabinet secretaries and they will be able to answer basically-but-specifically about the data associated with the current task, or generally about what their department does and is responsible for.

For simplicity sake the talking cabinet secretaries and president should be rendered as simple talking potatoes in the browser. 


*Problem/solution examples the agents will encounter, build system prompts for the to be able to handle this:

Problem: Farmers facing revenue shortfalls from drought
Orchestrator:  We need temporary funding to go to farmers, typically this is USDA programs, write a detailed ask for the Ag Secretary agent and dispatch

Problem: Military buildup in Europe deemed threatening
Orchestrator: These problems are typically handled by Both State and Defense departments, write up a coordinated mitigation/solution plan for both departments and actively coordinate the task to completion with them


