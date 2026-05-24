#!/bin/bash
TARGET="agent-app-leak"

while true; do
    # 1. 현재 날짜와 시간 가져오기 (예: 2026-05-24 14:00:00)
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

    # 2. TARGET 프로세스의 PID 가져오기
    PID=$(pgrep -o -f "/usr/local/bin/$TARGET")

    # 3. PID 존재 여부 체크 및 로그 출력
    if [ ! -z "$PID" ] && [[ "$PID" =~ ^[0-9]+$ ]]; then
        # ps 명령어로 CPU와 MEM(%) 수치 가져오기
        # 예시 로그의 MEM:5.1% 처럼 퍼센트(%) 단위를 맞추기 위해 %mem 옵션을 사용합니다.
        ps -p $PID -o %cpu,%mem --no-headers | awk -v t="$TIMESTAMP" -v name="$TARGET" '
        {
            # DISK와 FIREWALL은 예시 로그와 동일하게 고정값(또는 하드코딩)으로 처리
            printf "[%s] PROCESS:%s CPU:%s%% MEM:%s%% DISK:954G FIREWALL:active\n", t, name, $1, $2
        }'
    else
        # 프로세스가 죽었을 때의 로그 (필요에 따라 유지 혹은 생략 가능)
        echo "[$TIMESTAMP] PROCESS:$TARGET NOT RUNNING"
    fi

    # 예시 로그는 3분(180초) 간격이지만, OOM 테스트는 순식간에 끝나므로 
    # 원래 쓰시던 2초나 3초 주기로 지정하는 것을 추천합니다. (여기선 3초로 설정)
    sleep 3
done
