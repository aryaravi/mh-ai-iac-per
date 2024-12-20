import streamlit as st

from botocore.exceptions import EventStreamError
from boto3.session import Session

import time
import random

from util.prompt_templates.code_prompt import CODE_PROMPT
from util.prompt_templates.explain_prompt import EXPLAIN_PROMPT
from util.prompt_templates.sys_code_prompt import SYS_CODE_PROMPT
from util.prompt_templates.sys_explain_prompt import SYS_EXPLAIN_PROMPT
from util.prompt_templates.sys_update_prompt import SYS_UPDATE_PROMPT

from util.prompt_templates.code_prompt_terraform import CODE_PROMPT_TERRAFORM
from util.prompt_templates.sys_code_prompt_terraform import SYS_CODE_PROMPT_TERRAFORM
from util.prompt_templates.sys_update_prompt_terraform import SYS_UPDATE_PROMPT_TERRAFORM

from util.prompt_templates.code_prompt_mermaid import CODE_PROMPT_MERMAID
from util.prompt_templates.sys_code_prompt_mermaid import SYS_CODE_PROMPT_MERMAID
from util.prompt_templates.sys_update_prompt_mermaid import SYS_UPDATE_PROMPT_MERMAID

def invoke_model(
    modelId, inference_params, messages, system_prompt, data_placeholder=None
):
#    bedrock = Session().client(
#        service_name="bedrock-runtime",
#    )
#    result = str()
#    response = bedrock.converse_stream(
#        modelId=modelId,
#        messages=messages,
#        
#        system=[{"text": system_prompt}],
#        inferenceConfig={
#            "maxTokens": 4000,
#            "temperature": inference_params["temperature"],
#            "topP": inference_params["top_p"],
#        },
#        additionalModelRequestFields={"top_k": inference_params["top_k"]},
#    )
#
#    stream = response.get("stream")
#    if stream:
#        for event in stream:
#
#            if "contentBlockDelta" in event:
#                result += event["contentBlockDelta"]["delta"]["text"]
#                with data_placeholder.container():
#                    st.write(result)
# JPL mock
    st.write("modelId: ", modelId)    
    st.write(messages)
    st.write(system_prompt)
    result = "mock result"
    
    return result


def backoff_mechanism(
    func, modelId, inference_params, messages, system_prompt, data_placeholder=None
):
    MAX_RETRIES = 5  # Maximum number of retries
    INITIAL_DELAY = 1  # Initial delay in seconds
    MAX_DELAY = 60  # Maximum delay in second

    delay = INITIAL_DELAY
    retries = 0

    while retries < MAX_RETRIES:
        try:
            return func(
                modelId=modelId,
                inference_params=inference_params,
                messages=messages,
                system_prompt=system_prompt,
                data_placeholder=data_placeholder,
            )
        except EventStreamError as e:
            print(f"Retry {retries + 1}/{MAX_RETRIES}: {e}")
            time.sleep(delay + random.uniform(0, 1))  # Add a random jitter
            delay = min(delay * 2, MAX_DELAY)
            retries += 1


class ConvoChain:

    def get_explain_messages(self, image, image_type):
        messages = list()

        messages.append(
            {
                "role": "user",
                "content": [
                    {"text": EXPLAIN_PROMPT},
                    {
                        "image": {
                            "format": image_type,
                            "source": {
                                "bytes": image.getvalue(),
                            },
                        }
                    },
                ],
            }
        )

        return SYS_EXPLAIN_PROMPT, messages

    def read_examples(self, file_path):
        with open(file_path, "r") as template_file:
            return template_file.read()

    def get_code_messages(self, explain, template, examples):
        messages = list()

        if template == "CloudFormation":     
            messages.append(
                {
                    "role": "user",
                    "content": [
                        {
                            "text": f"""
                        Take this example CloudFormation YAML code as reference:
                            <example1>
                                {self.read_examples("data/examples/example1.yaml")}
                            </example1>
                            """
                        } if "example1" in examples else None,
                        {
                            "text": f"""
                        Take this example CloudFormation YAML code as reference:
                            <example2>
                                {self.read_examples("data/examples/example2.yaml")}
                            </example2>
                            """
                        } if "example2" in examples else None,
                        {
                            "text": f"""
                        Take this example CloudFormation YAML code as reference:
                            <example3>
                                {self.read_examples("data/examples/example3.yaml")}
                            </example3>
                            """
                        } if "example3" in examples else None,
                        {  
                            "text": f"""
                        Take this example CloudFormation YAML code as reference:
                            <example4>
                                {self.read_examples("data/examples/example4.yaml")}
                            </example4>
                            """
                        } if "example4" in examples else None,
                        {"text": CODE_PROMPT.replace("{{ explain }}", explain)},
                   ],
                }
            )
        elif template == "Terraform":
            messages.append(
                {
                    "role": "user",
                    "content": [
                        {
                            "text": f"""
                        Take this example Terraform HCL code as reference:
                            <example1>
                                {self.read_examples("data/examples/example1.hcl")}
                            </example1>      
                        """,
                        },
                        {
                            "text": f"""
                        Take this example Terraform HCL code as reference:
                            <example2>
                                {self.read_examples("data/examples/example2.hcl")}
                            </example2>
                        """,
                        },
                        {
                            "text": f"""
                        Take this example Terraform HCL code as reference:
                            <example3>
                                {self.read_examples("data/examples/example3.hcl")}
                            </example3>
                        """,
                        },
                        {"text": CODE_PROMPT_TERRAFORM.replace("{{ explain }}", explain)},
                    ],
                }
            )
        elif template == "Mermaid":
            messages.append(
                {
                    "role": "user",
                    "content": [
                        {
                            "text": f"""
                        Take this example Mermaid code as reference:
                            <example1>
                                {self.read_examples("data/examples/mermaid_example1.mer")}
                            </example1>      
                        """,
                        },
                        {"text": CODE_PROMPT_MERMAID.replace("{{ explain }}", explain)},
                    ],
                }
            )

        # Remove None values from the list
        messages[-1]["content"] = [msg for msg in messages[-1]["content"] if msg is not None]

        if template == "CloudFormation":     
            return SYS_CODE_PROMPT, messages
        elif template == "Terraform":
            return SYS_CODE_PROMPT_TERRAFORM, messages
        elif template == "Mermaid":
            return SYS_CODE_PROMPT_MERMAID, messages


    def get_update_messages(self, initial_cfn_code, explain, template, examples):
        messages = list()

        if template == "CloudFormation":
            messages.append(
                {
                    "role": "user",
                    "content": [
                        {
                            "text": f"""
                            Take this example CloudFormation YAML code as a reference <example1></example1>:
                            <example1>
                                {self.read_examples("data/examples/example1.yaml")}
                            </example1>
                            """
                        } if "example1" in examples else None,
                        {
                            "text": f"""
                            Take this example CloudFormation YAML code as a reference <example2></example2>:
                            <example2>
                                {self.read_examples("data/examples/example2.yaml")}
                            </example2>
                            """
                        } if "example2" in examples else None,
                        {
                            "text": f"""
                            Take this example CloudFormation YAML code as a reference <example3></example3>:
                            <example3>
                                {self.read_examples("data/examples/example3.yaml")}
                            </example3>
                            """
                        } if "example3" in examples else None,
                        {  
                            "text": f"""
                            Take this example CloudFormation YAML code as a reference <example4></example4>:
                            <example4>
                                {self.read_examples("data/examples/example4.yaml")}
                            </example4>
                            """
                        } if "example4" in examples else None,
                        {
                            "text": f"Step-by-step explanation of Architecture Diagram \n <explain> {explain} </explain>"
                        },
                   ],
                }
            )
        elif template == "Terraform":
            messages.append(
                {
                    "role": "user",
                    "content": [
                        {
                            "text": f"""
                        Take this example Terraform HCL code as a refernce <example1></example1>:
                            <example1>
                                {self.read_examples("data/examples/example1.hcl")}
                            </example1>      
                        """,
                        },
                        {
                            "text": f"""
                        Take this example Terraform HCL code as a refernce <example2></example2>:
                            <example2>
                                {self.read_examples("data/examples/example2.hcl")}
                            </example2>
                        """,
                        },
                        {
                            "text": f"""
                        Take this example Terraform HCL code as a refernce <example3></example3>:
                            <example3>
                                {self.read_examples("data/examples/example3.hcl")}
                            </example3>
                        """,
                        },
                        {
                            "text": f"Step-by-step explaination of Architecture Diagram \n <explain> {explain} </explain>",
                        },
                    ],
                }
            )
        elif template == "Mermaid":
            messages.append(
                {
                    "role": "user",
                    "content": [
                        {
                            "text": f"""
                        Take this example Mermaid code as reference:
                            <example1>
                                {self.read_examples("data/examples/mermaid_example1.mer")}
                            </example1>      
                        """,
                        },
                        {
                            "text": f"Step-by-step explaination of Architecture Diagram \n <explain> {explain} </explain>",
                        },
                    ],
                }
            )


        messages.append(
            {
                "role": "assistant",
                "content": [
                    {"text": initial_cfn_code},
                ],
            }
        )

        # Remove None values from the list
        messages[-1]["content"] = [msg for msg in messages[-1]["content"] if msg is not None]

        if template == "CloudFormation":     
            return SYS_UPDATE_PROMPT, messages
        elif template == "Terraform":
            return SYS_UPDATE_PROMPT_TERRAFORM, messages
        elif template == "Mermaid":
            return SYS_UPDATE_PROMPT_MERMAID, messages

