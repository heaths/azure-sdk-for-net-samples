FROM jupyter/base-notebook:ubuntu-22.04

ARG NB_USER=jovyan
ARG NB_UID=1000
ENV USER ${NB_USER} \
    NB_UID ${NB_UID} \
    HOME /home/${NB_USER}

USER root

# Install .NET dependencies.
ENV \
  DOTNET_RUNNING_IN_CONTAINER=true \
  DOTNET_USE_POLLING_FILE_WATCHER=true \
  NUGET_XMLDOC_MODE=skip \
  # Opt out of telemetry until after we install Jupyter when building the image to prevent caching of machine ID.
  DOTNET_INTERACTIVE_CLI_TELEMETRY_OPTOUT=true

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  curl \
  libc6 \
  libgcc1 \
  libgssapi-krb5-2 \
  libicu70 \
  libssl3 \
  libstdc++6 \
  zlib1g \
  && rm -rf /var/lib/apt/lists/

ARG DOTNET_SDK_VERSION=7.0.100
ENV DOTNET_SDK_VERSION=${DOTNET_SDK_VERSION}

# Install .NET SDK.
RUN curl -L https://dot.net/v1/dotnet-install.sh | bash -e -s -- --install-dir /usr/share/dotnet --version $DOTNET_SDK_VERSION \
 && ln -s /usr/share/dotnet/dotnet /usr/bin/dotnet \
 # Trigger first run experience.
 && dotnet sdk check

# Install Azure CLI.
curl -sL https://aka.ms/InstallAzureCLIDeb | /usr/bin/bash

# Switch back to NB_USER to complete installs.
RUN chown -R ${NB_UID} ${HOME}
USER ${NB_UID}

# Install user packages.
RUN pip install --upgrade ipykernel \
 && pip install nteract_on_jupyter

RUN dotnet tool install -g Microsoft.dotnet-interactive --add-source "https://pkgs.dev.azure.com/dnceng/public/_packaging/dotnet-tools/nuget/v3/index.json"
ENV PATH="${PATH}:${HOME}/.dotnet/tools"

# Install .NET kernel.
RUN dotnet interactive jupyter install

# Enable telemetry once Jupyter is installed.
ENV DOTNET_INTERACTIVE_CLI_TELEMETRY_OPTOUT=false

# Copy samples.
COPY --chown=${NB_UID} README.md ${HOME}/notebooks/
COPY --chown=${NB_UID} sdk/ ${HOME}/notebooks/sdk/

WORKDIR ${HOME}/notebooks/
