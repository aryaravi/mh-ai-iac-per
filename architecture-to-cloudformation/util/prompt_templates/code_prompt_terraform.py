CODE_PROMPT_TERRAFORM ="""
Create Terraform tf code only for AWS Servies present in <explain></explain>

<explain>
{{ explain }}
</explain>

Mimic the practices of example Terraform tf templates.

- Use Terraform tf Pseudo parameters where necessary.
- Add into description "This template is not production ready and should only be used for inspiration"
Do not return examples or explaination, only return the generated Terraform tf template encapsulated between triple backticks (``` ```). Skip the preamble. Think step-by-step.
"""