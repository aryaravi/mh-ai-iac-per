import streamlit as st

import util
from argparse import ArgumentParser

parser = ArgumentParser()
parser.add_argument("--modelId", type=str, default=None)

args = parser.parse_args()
st.set_page_config(
    page_title="AWS",
    page_icon="👋",
    layout="wide",
)

modelId = args.modelId

st.header("Architecture to CloudFormation")

# Using object notation

st.sidebar.header("Inference Parameters")
Temperature = st.sidebar.slider(
    "Temperature", min_value=0.0, max_value=1.0, step=0.1, value=0.0
)
Top_P = st.sidebar.slider("Top P", min_value=0.0, max_value=1.0, step=0.001, value=1.0)
Top_K = st.sidebar.slider("Top K", min_value=0, max_value=500, step=1, value=250)

# JPL adding modelId override
if modelId is None:
    modelId = "anthropic.claude-3-sonnet-20240229-v1:0"
    
modelId2 = "anthropic.claude-3-opus-20240229-v1:0"
modelId3 = "anthropic.claude-3-5-sonnet-20240620-v1:0"
modelId4 = "anthropic.claude-3-5-sonnet-20241022-v2:0"
modelId5 = "anthropic.claude-3-5-haiku-20241022-v1:0"

# JPL adding modelId selection
modelId = st.sidebar.selectbox(
    "Select Model ID",
    [modelId, modelId2, modelId3, modelId4, modelId5],
)

# JPL adding example selection
examples = st.sidebar.multiselect(
    "Select Examples",
    ["example1", "example2", "example3", "example4"],
)

# JPL adding CloudFormation Template / Terraform Template selection
template = st.sidebar.selectbox(
    "Select Template",
    ["CloudFormation", "Terraform", "Mermaid","FedRAMP",],
)

bedrock = util.Model(
    modelId=modelId,
    inference_params={"temperature": Temperature, "top_p": Top_P, "top_k": Top_K},
    template=template,
    examples=examples,
)

if st.button("Clear", type="secondary"):
    uploaded_file = None
    bedrock.clear_memory()
    bedrock.clear_explain()
    st.rerun()

uploaded_file = st.file_uploader(
    "Upload an Architecture diagram to generate AWS CloudFormation code",
    type=["jpeg", "png"],
    disabled=bool(bedrock.get_explain()),
)

if uploaded_file is not None:

    image, explain = st.columns((5, 5))

    with image:
        st.image(uploaded_file.getvalue())

    with explain:

        if bedrock.get_explain():
            st.write(bedrock.get_explain())
        else:
            explain_placeholder = st.empty()
            bedrock.invoke_explain_model(
                uploaded_file,
                uploaded_file.type.replace("image/", ""),
                explain_placeholder,
            )

    if bedrock.check_memory():
        role = "assistant"
        for chat in bedrock.return_memory():
            role = "human" if chat["role"] == "user" else "assistant"
            content = chat["content"][0]["text"]
            with st.chat_message(role):
                st.markdown(content)


    if not bedrock.check_memory():
        with st.chat_message("assistant"):
            code_placeholder = st.empty()

            bedrock.invoke_code_model(code_placeholder)

    if prompt := st.chat_input(
        "Give the bot instructions to update stack...",
    ):
        with st.chat_message("human"):
            st.markdown(prompt)

        with st.chat_message("assistant"):
            if bedrock.check_memory():
                update_placeholder = st.empty()
                bedrock.invoke_update_model(prompt, update_placeholder)
