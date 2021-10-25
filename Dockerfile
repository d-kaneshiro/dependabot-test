# ARG PYTHON_VERSION=3.9.1
# FROM python:${PYTHON_VERSION}-buster
FROM python:3.9.1-buster

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Tokyo
RUN echo $TZ > /etc/timezone

ARG WORKDIR=/test
WORKDIR ${WORKDIR}

# Or your actual UID, GID on Linux if not the default 1000
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# change default shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN chsh -s /bin/bash

# Increase timeout for apt-get to 300 seconds
RUN /bin/echo -e "\n\
    Acquire::http::Timeout \"300\";\n\
    Acquire::ftp::Timeout \"300\";" >> /etc/apt/apt.conf.d/99timeout

# Configure apt and install packages
RUN rm -rf /var/lib/apt/lists/* \
    && apt-get update \
    && apt-get -y --no-install-recommends install sudo vim tzdata less graphviz \
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# install node
# https://github.com/nodesource/distributions/blob/master/README.md#installation-instructions
RUN curl -sL https://deb.nodesource.com/setup_12.x | bash - \
    && apt-get install --no-install-recommends -y nodejs

# hadolint ignore=DL3013
RUN pip install --no-cache-dir -U pip

# postgres install
RUN bash -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' \
    && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
    && apt-get update \
    && apt-get install --no-install-recommends -y postgresql \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user to use if preferred - see https://aka.ms/vscode-remote/containers/non-root-user.
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd -s /bin/bash --uid $USER_UID --gid $USER_GID -m $USERNAME \
    # Add sudo support for non-root user
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

# terminal setting
RUN wget --progress=dot:giga https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.bash -O /home/vscode/.git-completion.bash \
    && wget --progress=dot:giga https://raw.githubusercontent.com/git/git/master/contrib/completion/git-prompt.sh -O /home/vscode/.git-prompt.sh \
    && chmod a+x /home/vscode/.git-completion.bash \
    && chmod a+x /home/vscode/.git-prompt.sh \
    && echo -e "\n\
    source ~/.git-completion.bash\n\
    source ~/.git-prompt.sh\n\
    export PS1='\\[\\e]0;\\u@\\h: \\w\\a\\]\${debian_chroot:+(\$debian_chroot)}\\[\\033[01;32m\\]\\u\\[\\033[00m\\]:\\[\\033[01;34m\\]\\w\\[\\033[00m\\]\\[\\033[1;30m\\]\$(__git_ps1)\\[\\033[0m\\] \\$ '\n\
    " >>  /home/vscode/.bashrc

# install hadolint
RUN wget --progress=dot:giga https://github.com/hadolint/hadolint/releases/download/v2.7.0/hadolint-Linux-x86_64 -O /usr/local/bin/hadolint \
    && chmod +x /usr/local/bin/hadolint

# install npm packages
COPY ./docs/package.json ${WORKDIR}/docs/package.json
COPY ./docs/package-lock.json ${WORKDIR}/docs/package-lock.json
RUN npm install --prefix ${WORKDIR}/docs \
    && npm install --global pyright

# copy requirements files
COPY ./requirements.txt /tmp/requirements.txt
COPY ./requirements-dev.txt /tmp/requirements-dev.txt

# library install
RUN pip install --no-cache-dir -r /tmp/requirements.txt -r /tmp/requirements-dev.txt

ENV DEBIAN_FRONTEND=

CMD ["/bin/bash"]
