FROM node:22-alpine

ARG AGENT_NATIVE_VERSION=0.63.4

WORKDIR /repo

RUN npm install --global "@agent-native/core@${AGENT_NATIVE_VERSION}"

COPY . /repo

ENV PLAN_DIR=/repo/plans/agent-native-companion-replacement
ENV PLAN_KIND=plan
ENV PORT=8080
EXPOSE 8080

CMD ["node", "scripts/docker-agent-native-preview.mjs"]
