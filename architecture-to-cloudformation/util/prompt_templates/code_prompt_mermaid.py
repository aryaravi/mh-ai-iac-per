CODE_PROMPT_MERMAID ="""
Create Mermaid code only for AWS Servies present in <explain></explain>

<explain>
{{ explain }}
</explain>

Mimic the practices of example Mermaid templates.

Do not return examples or explaination, only return the generated Mermaid code encapsulated between triple backticks (``` ```). Skip the preamble. Think step-by-step.
"""