# Changed base to Ubuntu 24.04
FROM ubuntu:25.04

ARG DEBIAN_FRONTEND=noninteractive
ARG TERRAFORM_VERSION="1.15.8"
ARG HOST_ARCH="amd64"
ARG INSTALL_AZURE_CLI="NO"
ARG INSTALL_AWS_CLI="NO"
ARG INSTALL_GCP_CLI="NO"
ARG INSTALL_CHECKOV="NO"

# Validate required build args
RUN if [ -z "${TERRAFORM_VERSION}" ]; then \
      echo "ERROR: TERRAFORM_VERSION is required" && exit 1; \
    fi \
 && if [ "${HOST_ARCH}" != "amd64" ] && [ "${HOST_ARCH}" != "arm64" ]; then \
      echo "ERROR: HOST_ARCH must be 'amd64' or 'arm64', got '${HOST_ARCH}'" && exit 1; \
    fi

# Base tools + sudo
RUN apt-get update && apt-get install --yes --no-install-recommends \
      curl unzip git wget bash less software-properties-common lsb-release bash-completion sudo \
      iputils-ping dnsutils traceroute less groff man-db \
  && rm -rf /var/lib/apt/lists/*

# Terraform (linux_amd64 or linux_arm64)
RUN curl -Lo /tmp/terraform.zip "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${HOST_ARCH}.zip" \
 && unzip /tmp/terraform.zip -d /usr/local/bin \
 && rm /tmp/terraform.zip

# Install Terraform Lint
RUN curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash
# Install TfSec
RUN curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash

# Azure CLI (conditional)
RUN if [ "${INSTALL_AZURE_CLI}" = "YES" ]; then \
    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash; \
  fi

# AWS CLI (conditional)
RUN if [ "${INSTALL_AWS_CLI}" = "YES" ]; then \
    if [ "${HOST_ARCH}" = "amd64" ]; then AWS_ARCH="x86_64"; else AWS_ARCH="aarch64"; fi && \
    curl "https://awscli.amazonaws.com/awscli-exe-linux-${AWS_ARCH}.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf awscliv2.zip ./aws; \
  fi

# GCP CLI (conditional)
RUN if [ "${INSTALL_GCP_CLI}" = "YES" ]; then \
    if [ "${HOST_ARCH}" = "amd64" ]; then GCP_ARCH="x86_64"; else GCP_ARCH="arm"; fi && \
    curl -O "https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-${GCP_ARCH}.tar.gz" && \
    tar -xf google-cloud-cli-linux-${GCP_ARCH}.tar.gz -C /usr/local/ && \
    /usr/local/google-cloud-sdk/install.sh --usage-reporting=false --command-completion=false --path-update=false --quiet && \
    rm google-cloud-cli-linux-${GCP_ARCH}.tar.gz && \
    ln -s /usr/local/google-cloud-sdk/bin/gcloud /usr/local/bin/gcloud && \
    ln -s /usr/local/google-cloud-sdk/bin/gsutil /usr/local/bin/gsutil && \
    ln -s /usr/local/google-cloud-sdk/bin/bq /usr/local/bin/bq; \
  fi

# Checkov (conditional)
RUN if [ "${INSTALL_CHECKOV}" = "YES" ]; then \
    apt-get update && apt-get install --yes --no-install-recommends python3-pip python3-venv && \
    python3 -m venv /opt/checkov-venv && \
    /opt/checkov-venv/bin/pip install --no-cache-dir checkov && \
    ln -s /opt/checkov-venv/bin/checkov /usr/local/bin/checkov && \
    rm -rf /var/lib/apt/lists/*; \
  fi

# Create user and grant passwordless sudo
RUN adduser --disabled-password --gecos "" tfuser \
 && usermod --append --groups sudo tfuser \
 && echo 'tfuser ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/90-tfuser \
 && chmod 0440 /etc/sudoers.d/90-tfuser

## Customization to show the current terraform workspace
USER tfuser
RUN echo 'if [ -f /etc/bash_completion ]; then . /etc/bash_completion; fi' >> /home/tfuser/.bashrc \
 && echo '' >> /home/tfuser/.bashrc \
 && echo '# Function to get current Terraform workspace' >> /home/tfuser/.bashrc \
 && echo 'tf_workspace() {' >> /home/tfuser/.bashrc \
 && echo '  if [ -d .terraform ]; then' >> /home/tfuser/.bashrc \
 && echo '    local ws=$(terraform workspace show 2>/dev/null)' >> /home/tfuser/.bashrc \
 && echo '    if [ -n "$ws" ]; then' >> /home/tfuser/.bashrc \
 && echo '      echo " ($ws)"' >> /home/tfuser/.bashrc \
 && echo '    fi' >> /home/tfuser/.bashrc \
 && echo '  fi' >> /home/tfuser/.bashrc \
 && echo '}' >> /home/tfuser/.bashrc \
 && echo '' >> /home/tfuser/.bashrc \
 && echo 'alias tf="terraform" ' >> /home/tfuser/.bashrc \
 && echo '# Custom prompt with Terraform workspace' >> /home/tfuser/.bashrc \
 && echo 'PS1="\[\e[32m\]\u@\h\[\e[0m\] : \[\e[34m\]\w\[\e[0m\] :\[\e[33m\]\$(tf_workspace)\[\e[0m\] \\$ "' >> /home/tfuser/.bashrc

CMD ["tail", "-f", "/dev/null"]
