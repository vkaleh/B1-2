# 리눅스 프로세스 및 시스템 리소스 트러블슈팅
## 1. 프로젝트 개요

## 2. 시스템 장애 분석 및 이슈 리포트
### 2-1. OOM Crash
#### 2-1-1. 실행 로그 
1차 (MEMORY_LIMIT=60)
```bash
agent-admin@415865874d7f:~$ /usr/local/bin/agent-app-leak
>>> Starting Agent Boot Sequence...
[1/6] Checking User Account               [OK]
   ... Running as service user 'agent-admin' (uid=1001)
[2/6] Verifying Environment Variables     [OK]
   ... All required Envs correct
[3/6] Checking Required Files             [OK]
   ... Verified 'secret.key' with correct key string.
[4/6] Checking Port Availability          [OK]
   ... Port 15034 is available.
[5/6] Verifying Log Permission            [OK]
   ... Log directory is writable: /var/log/agent-app
[6/6] Verifying Mission Environment       [OK]
   ... MEMORY_LIMIT=60MB, CPU_MAX_OCCUPY=20%, MULTI_THREAD_ENABLE=False
------------------------------------------------------------
All Boot Checks Passed!
Agent READY
2026-05-24 13:59:33,612 [INFO] [SafetyGuard] Process priority lowered (nice=10).
2026-05-24 13:59:33,612 [INFO] Agent listening at port 15034

==================================================
 [ Agent Initiate ] Resource Check 
==================================================
 [ MEMORY ] Limit: 60MB 		[ WARNING: Recommend Over 256MB ]
 [ CPU    ] Limit: 20%  		[ OK ]
 [ THREAD ] Concurrency: False 		[ OK ]
--------------------------------------------------
 >>> SYSTEM STATUS: STABLE. STARTING WORKLOAD MONITORING...
==================================================

2026-05-24 13:59:35,651 [INFO] [MemoryWorker] Current Heap: 25MB
2026-05-24 13:59:38,692 [INFO] [MemoryWorker] Current Heap: 50MB
2026-05-24 13:59:41,730 [INFO] [MemoryWorker] Current Heap: 75MB
2026-05-24 13:59:41,730 [CRITICAL] [MemoryGuard] Memory limit exceeded (75MB >= 60MB) / (Recommend Over 256MB)
2026-05-24 13:59:41,730 [CRITICAL] [MemoryGuard] Self-terminating process 3501 to prevent system instability.


>>> [SYSTEM] SELF-TERMINATED (Memory Limit Exceeded) <<<

Killed
```
<br>

2차 (MEMORY_LIMIT=120)
```bash
agent-admin@415865874d7f:~$ /usr/local/bin/agent-app-leak
>>> Starting Agent Boot Sequence...
[1/6] Checking User Account               [OK]
   ... Running as service user 'agent-admin' (uid=1001)
[2/6] Verifying Environment Variables     [OK]
   ... All required Envs correct
[3/6] Checking Required Files             [OK]
   ... Verified 'secret.key' with correct key string.
[4/6] Checking Port Availability          [OK]
   ... Port 15034 is available.
[5/6] Verifying Log Permission            [OK]
   ... Log directory is writable: /var/log/agent-app
[6/6] Verifying Mission Environment       [OK]
   ... MEMORY_LIMIT=120MB, CPU_MAX_OCCUPY=20%, MULTI_THREAD_ENABLE=False
------------------------------------------------------------
All Boot Checks Passed!
Agent READY
2026-05-24 14:50:02,660 [INFO] [SafetyGuard] Process priority lowered (nice=10).
2026-05-24 14:50:02,661 [INFO] Agent listening at port 15034

==================================================
 [ Agent Initiate ] Resource Check 
==================================================
 [ MEMORY ] Limit: 120MB 		[ WARNING: Recommend Over 256MB ]
 [ CPU    ] Limit: 20%  		[ OK ]
 [ THREAD ] Concurrency: False 		[ OK ]
--------------------------------------------------
 >>> SYSTEM STATUS: STABLE. STARTING WORKLOAD MONITORING...
==================================================

2026-05-24 14:50:04,701 [INFO] [MemoryWorker] Current Heap: 25MB
2026-05-24 14:50:07,743 [INFO] [MemoryWorker] Current Heap: 50MB
2026-05-24 14:50:10,785 [INFO] [MemoryWorker] Current Heap: 75MB
2026-05-24 14:50:13,827 [INFO] [MemoryWorker] Current Heap: 100MB
2026-05-24 14:50:16,863 [INFO] [MemoryWorker] Current Heap: 125MB
2026-05-24 14:50:16,864 [CRITICAL] [MemoryGuard] Memory limit exceeded (125MB >= 120MB) / (Recommend Over 256MB)
2026-05-24 14:50:16,864 [CRITICAL] [MemoryGuard] Self-terminating process 7270 to prevent system instability.


>>> [SYSTEM] SELF-TERMINATED (Memory Limit Exceeded) <<<

Killed
```
<br>

#### 2-1-2. [Bug] 프로세스 실행 6초 후 메모리 보호 정책에 의한 비정상 강제 종료 (OOM)

##### 1. Description (현상 설명)
agent-app-leak 애플리케이션을 실행하고 약 6초가 경과하면, 터미널에 SELF-TERMINATED 메시지가 출력되며 프로세스가 예고 없이 종료됨 <br>

##### 2. Evidence & Logs (증거 자료)
애플리케이션 실행 로그를 분석한 결과, 처음엔 25MB 수준이던 Heap 메모리가 3초 간격으로 25MB씩 선형적으로 상승하는 패턴을 보였음 <br>
주입된 임계치인 120MB를 초과하는 순간 프로세스가 즉시 종료되었음 <br>

① monitor.sh 결과 (메모리 및 CPU 시스템 자원 관제 로그)
```bash
[2026-05-24 14:49:58] PROCESS:agent-app-leak NOT RUNNING
[2026-05-24 14:50:01] PROCESS:agent-app-leak NOT RUNNING
[2026-05-24 14:50:04] PROCESS:agent-app-leak CPU:5.1% MEM:0.0% DISK:954G FIREWALL:active
[2026-05-24 14:50:07] PROCESS:agent-app-leak CPU:2.2% MEM:0.0% DISK:954G FIREWALL:active
[2026-05-24 14:50:10] PROCESS:agent-app-leak CPU:1.4% MEM:0.0% DISK:954G FIREWALL:active
[2026-05-24 14:50:13] PROCESS:agent-app-leak CPU:1.0% MEM:0.0% DISK:954G FIREWALL:active
[2026-05-24 14:50:16] PROCESS:agent-app-leak CPU:0.8% MEM:0.0% DISK:954G FIREWALL:active
[2026-05-24 14:50:19] PROCESS:agent-app-leak NOT RUNNING
[2026-05-24 14:50:22] PROCESS:agent-app-leak NOT RUNNING
```

프로세스가 정상 종료 상태(NOT RUNNING)였다가 재실행되면서 CPU 점유율이 순간적으로 상승 <br>
<br>

② 종료 직전/직후 실행 로그 (애플리케이션 내부 로그)
```bash
2026-05-24 14:50:04,701 [INFO] [MemoryWorker] Current Heap: 25MB
2026-05-24 14:50:07,743 [INFO] [MemoryWorker] Current Heap: 50MB
2026-05-24 14:50:10,785 [INFO] [MemoryWorker] Current Heap: 75MB
2026-05-24 14:50:13,827 [INFO] [MemoryWorker] Current Heap: 100MB
2026-05-24 14:50:16,863 [INFO] [MemoryWorker] Current Heap: 125MB
2026-05-24 14:50:16,864 [CRITICAL] [MemoryGuard] Memory limit exceeded (125MB >= 120MB) / (Recommend Over 256MB)
2026-05-24 14:50:16,864 [CRITICAL] [MemoryGuard] Self-terminating process 7270 to prevent system instability.


>>> [SYSTEM] SELF-TERMINATED (Memory Limit Exceeded) <<<

Killed
```

설정된 메모리 임계치(120MB)를 초과하는 순간 애플리케이션 내부 감시 장치(MemoryGuard) 정책에 의해 프로세스가 비정상 강제 종료(OOM)됨 <br>
<br>

### 2-2. CPU Latency

### 2-3. Deadlock


## 3. 수행 방법 

환경 변수 설정
```bash
root@415865874d7f:/# vi /etc/bash.bashrc

export AGENT_HOME=/home/agent-admin/agent-app
export AGENT_PORT=15034
export AGENT_UPLOAD_DIR=$AGENT_HOME/upload_files
export AGENT_KEY_PATH=$AGENT_HOME/api_keys
export AGENT_LOG_DIR=/var/log/agent-app
export MEMORY_LIMIT=60
export CPU_MAX_OCCUPY=20
export MULTI_THREAD_ENABLE=1
```
<br>       

monitor.sh 작성 
<details>
  <summary>monitor.sh 코드 </summary> 
  
```bash
root@415865874d7f:/# vi /home/agent-admin/agent-app/bin/monitor.sh
```
<br>

```bash
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
```
</details>  
<br>

```bash
root@415865874d7f:/# su - agent-admin
agent-admin@415865874d7f:~$ export MULTI_THREAD_ENABLE=0
agent-admin@415865874d7f:~$ export MEMORY_LIMIT=60
agent-admin@415865874d7f:~$ /usr/local/bin/agent-app-leak
-bash: /usr/local/bin/agent-app-leak: Permission denied
```
<br>

agent-app-leak 권한 설정
```bash
root@415865874d7f:/# chmod +x /usr/local/bin/agent-app-leak
```
<br>

```bash
agent-admin@415865874d7f:~$ /usr/local/bin/agent-app-leak
>>> Starting Agent Boot Sequence...
[1/6] Checking User Account               [OK]
   ... Running as service user 'agent-admin' (uid=1001)
[2/6] Verifying Environment Variables     [FAIL]
   >>> Directory not found: /home/agent-admin/agent-app/upload_files
[3/6] Checking Required Files             [FAIL]
   >>> Skipped due to previous critical failure.
[4/6] Checking Port Availability          [FAIL]
   >>> Skipped due to previous critical failure.
[5/6] Verifying Log Permission            [FAIL]
   >>> Skipped due to previous critical failure.
[6/6] Verifying Mission Environment       [FAIL]
   >>> Skipped due to previous critical failure.
--------------------------------------------------
System Boot Failed. Process Terminated.
```
<br>

upload_files 폴더 생성
```bash
root@415865874d7f:/# mkdir /home/agent-admin/agent-app/upload_files
```
<br>

monitor.log 초기화
```bash
root@415865874d7f:/# pkill -f monitor.sh            # 기존에 실행중인 프로세스 종료   
root@415865874d7f:/# true > /var/log/monitor.log    # 기존 로그 파일 초기화 
root@415865874d7f:/# cat /var/log/monitor.log       # 아무것도 안 뜨는지 확인 
```
<br>

monitor.log 실행
```bash
# 백그라운드에서 감시 스크립트가 돌아가도록 실행
root@415865874d7f:/# .//home/agent-admin/agent-app/bin/monitor.sh >> /var/log/monitor.log &    
[1] 7262

# 실시간으로 쌓이는 로그 확인하려면
root@415865874d7f:/# tail -f /var/log/monitor.log
[2026-05-24 14:49:58] PROCESS:agent-app-leak NOT RUNNING
[2026-05-24 14:50:01] PROCESS:agent-app-leak NOT RUNNING
[2026-05-24 14:50:04] PROCESS:agent-app-leak CPU:5.1% MEM:0.0% DISK:954G FIREWALL:active    
[2026-05-24 14:50:07] PROCESS:agent-app-leak CPU:2.2% MEM:0.0% DISK:954G FIREWALL:active
[2026-05-24 14:50:10] PROCESS:agent-app-leak CPU:1.4% MEM:0.0% DISK:954G FIREWALL:active
[2026-05-24 14:50:13] PROCESS:agent-app-leak CPU:1.0% MEM:0.0% DISK:954G FIREWALL:active
[2026-05-24 14:50:16] PROCESS:agent-app-leak CPU:0.8% MEM:0.0% DISK:954G FIREWALL:active
[2026-05-24 14:50:19] PROCESS:agent-app-leak NOT RUNNING
[2026-05-24 14:50:22] PROCESS:agent-app-leak NOT RUNNING
```
<br>

다른 터미널에서 agent-app-leak 실행 <br>
<br>

