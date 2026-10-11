# Образ лабы: bash 5 + привычные GNU-утилиты (в чистом bash:5 они «урезанные» от busybox)
FROM bash:5
RUN apk add --no-cache coreutils findutils grep sed gawk util-linux procps shellcheck jq curl diffutils
WORKDIR /work
CMD ["bash"]
