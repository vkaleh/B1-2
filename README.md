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
#### 2-2-1. 실행 로그
1차 시도 (CPU_MAX_OCCUPY = 10)
```bash
agent-admin@c37974f555e9:~$ export CPU_MAX_OCCUPY=10
agent-admin@c37974f555e9:~$ /usr/local/bin/agent-app-leak
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
   ... MEMORY_LIMIT=512MB, CPU_MAX_OCCUPY=10%, MULTI_THREAD_ENABLE=False
------------------------------------------------------------
All Boot Checks Passed!
Agent READY
2026-05-25 13:32:08,009 [INFO] [SafetyGuard] Process priority lowered (nice=10).
2026-05-25 13:32:08,009 [INFO] Agent listening at port 15034

==================================================
 [ Agent Initiate ] Resource Check 
==================================================
 [ MEMORY ] Limit: 512MB 		[ OK ]
 [ CPU    ] Limit: 10%  		[ OK ]
 [ THREAD ] Concurrency: False 		[ OK ]
--------------------------------------------------
 >>> SYSTEM STATUS: STABLE. STARTING WORKLOAD MONITORING...
==================================================

2026-05-25 13:32:10,012 [INFO] >>> Scenario Selected: [Healthy System Monitoring]

>>> [SYSTEM] ALL CONFIGURATIONS OPTIMAL. RUNNING STABILITY TEST... <<<

2026-05-25 13:32:10,012 [INFO] [Scheduler] Task Scheduler Initialized.
2026-05-25 13:32:10,013 [INFO] [Scheduler] Registered Tasks: ['Thread-A', 'Thread-B', 'Thread-C']
2026-05-25 13:32:10,013 [INFO] [Scheduler] Starting task execution...
2026-05-25 13:32:10,013 [INFO] [Thread-A] Task Started. Calculating... (20%)
2026-05-25 13:32:10,064 [INFO] [Thread-A] Calculating... (40%)
2026-05-25 13:32:10,116 [INFO] [Thread-A] Calculating... (60%)
2026-05-25 13:32:10,167 [INFO] [Thread-A] Calculating... (80%)
2026-05-25 13:32:10,218 [INFO] [Thread-A] Task Completed. (100%)
2026-05-25 13:32:10,269 [INFO] [Thread-B] Task Started. Calculating... (20%)
2026-05-25 13:32:10,321 [INFO] [Thread-B] Calculating... (40%)
2026-05-25 13:32:10,372 [INFO] [Thread-B] Calculating... (60%)
2026-05-25 13:32:10,424 [INFO] [Thread-B] Calculating... (80%)
2026-05-25 13:32:10,475 [INFO] [Thread-B] Task Completed. (100%)
2026-05-25 13:32:10,527 [INFO] [Thread-C] Task Started. Calculating... (20%)
2026-05-25 13:32:10,579 [INFO] [Thread-C] Calculating... (40%)
2026-05-25 13:32:10,630 [INFO] [Thread-C] Calculating... (60%)
2026-05-25 13:32:10,682 [INFO] [Thread-C] Calculating... (80%)
2026-05-25 13:32:10,733 [INFO] [Thread-C] Task Completed. (100%)
2026-05-25 13:32:10,785 [INFO] [Scheduler] All tasks completed.
2026-05-25 13:32:10,805 [INFO] [MemoryWorker] Current Heap: 25MB
2026-05-25 13:32:10,805 [INFO] [CpuWorker] Started. Maximum CPU Limit: 10%
2026-05-25 13:32:10,805 [INFO] [CpuWorker] Current Load: 5.00%
2026-05-25 13:32:13,846 [INFO] [MemoryWorker] Current Heap: 50MB
2026-05-25 13:32:13,910 [INFO] [CpuWorker] Current Load: 6.27%
2026-05-25 13:32:16,013 [INFO] [CpuWorker] Peak reached (10.00%). Starting cooldown...
2026-05-25 13:32:16,885 [INFO] [MemoryWorker] Current Heap: 75MB
2026-05-25 13:32:17,015 [INFO] [CpuWorker] Current Load: 10.00%
2026-05-25 13:32:19,925 [INFO] [MemoryWorker] Current Heap: 100MB
2026-05-25 13:32:20,120 [INFO] [CpuWorker] Current Load: 8.85%
2026-05-25 13:32:22,225 [INFO] [CpuWorker] Cooldown complete (5.00%). Resuming load increase...
2026-05-25 13:32:22,967 [INFO] [MemoryWorker] Current Heap: 125MB
2026-05-25 13:32:23,227 [INFO] [CpuWorker] Current Load: 5.00%
2026-05-25 13:32:25,331 [INFO] [CpuWorker] Peak reached (10.00%). Starting cooldown...
2026-05-25 13:32:26,009 [INFO] [MemoryWorker] Current Heap: 150MB
2026-05-25 13:32:26,333 [INFO] [CpuWorker] Current Load: 10.00%
2026-05-25 13:32:29,048 [INFO] [MemoryWorker] Current Heap: 175MB
2026-05-25 13:32:29,437 [INFO] [CpuWorker] Current Load: 6.62%
2026-05-25 13:32:32,087 [INFO] [MemoryWorker] Current Heap: 200MB
2026-05-25 13:32:32,543 [INFO] [CpuWorker] Current Load: 6.50%
2026-05-25 13:32:34,648 [INFO] [CpuWorker] Cooldown complete (5.00%). Resuming load increase...
2026-05-25 13:32:35,127 [INFO] [MemoryWorker] Current Heap: 225MB
2026-05-25 13:32:35,650 [INFO] [CpuWorker] Current Load: 5.00%
2026-05-25 13:32:38,168 [INFO] [MemoryWorker] Current Heap: 250MB
2026-05-25 13:32:38,756 [INFO] [CpuWorker] Current Load: 9.68%
2026-05-25 13:32:40,858 [INFO] [CpuWorker] Peak reached (10.00%). Starting cooldown...
2026-05-25 13:32:41,210 [INFO] [MemoryWorker] Current Heap: 275MB
2026-05-25 13:32:41,860 [INFO] [CpuWorker] Current Load: 10.00%
2026-05-25 13:32:43,963 [INFO] [CpuWorker] Cooldown complete (5.00%). Resuming load increase...
2026-05-25 13:32:44,249 [INFO] [MemoryWorker] Current Heap: 300MB
2026-05-25 13:32:44,966 [INFO] [CpuWorker] Current Load: 5.00%
2026-05-25 13:32:47,291 [INFO] [MemoryWorker] Current Heap: 325MB
2026-05-25 13:32:48,071 [INFO] [CpuWorker] Current Load: 6.12%
2026-05-25 13:32:50,180 [INFO] [CpuWorker] Peak reached (10.00%). Starting cooldown...
2026-05-25 13:32:50,298 [INFO] [MemoryWorker] Current Heap: 350MB
2026-05-25 13:32:51,182 [INFO] [CpuWorker] Current Load: 10.00%
2026-05-25 13:32:53,284 [INFO] [CpuWorker] Cooldown complete (5.00%). Resuming load increase...
2026-05-25 13:32:53,310 [INFO] [MemoryWorker] Current Heap: 375MB
2026-05-25 13:32:54,286 [INFO] [CpuWorker] Current Load: 5.00%
2026-05-25 13:32:56,352 [INFO] [MemoryWorker] Current Heap: 400MB
2026-05-25 13:32:56,390 [INFO] [CpuWorker] Peak reached (10.00%). Starting cooldown...
2026-05-25 13:32:57,392 [INFO] [CpuWorker] Current Load: 10.00%
2026-05-25 13:32:59,392 [INFO] [MemoryWorker] Current Heap: 425MB
2026-05-25 13:33:00,496 [INFO] [CpuWorker] Current Load: 8.36%
2026-05-25 13:33:02,430 [INFO] [MemoryWorker] Current Heap: 450MB
2026-05-25 13:33:02,600 [INFO] [CpuWorker] Cooldown complete (5.00%). Resuming load increase...
2026-05-25 13:33:03,602 [INFO] [CpuWorker] Current Load: 5.00%
2026-05-25 13:33:05,471 [INFO] [MemoryWorker] Current Heap: 475MB
2026-05-25 13:33:05,706 [INFO] [CpuWorker] Peak reached (10.00%). Starting cooldown...
2026-05-25 13:33:06,708 [INFO] [CpuWorker] Current Load: 10.00%
2026-05-25 13:33:08,512 [INFO] [MemoryWorker] Current Heap: 500MB
2026-05-25 13:33:09,814 [INFO] [CpuWorker] Current Load: 6.98%
2026-05-25 13:33:11,553 [INFO] [MemoryWorker] Current Heap: 525MB
2026-05-25 13:33:11,553 [WARNING] [MemoryWorker] Memory Usage Reached Limit (525MB). Starting cleanup...
2026-05-25 13:33:11,563 [INFO] [System] Memory Cache Flushed. Process Stabilized.

>>> [SYSTEM] MEMORY RECOVERED (Cache Cleared) <<<

2026-05-25 13:33:11,918 [INFO] [CpuWorker] Cooldown complete (5.00%). Resuming load increase...
2026-05-25 13:33:12,919 [INFO] [CpuWorker] Current Load: 5.00%
2026-05-25 13:33:15,022 [INFO] [CpuWorker] Peak reached (10.00%). Starting cooldown...
2026-05-25 13:33:16,024 [INFO] [CpuWorker] Current Load: 10.00%
2026-05-25 13:33:16,573 [INFO] [MemoryWorker] Current Heap: 25MB
2026-05-25 13:33:19,130 [INFO] [CpuWorker] Current Load: 7.35%
2026-05-25 13:33:19,582 [INFO] [MemoryWorker] Current Heap: 50MB
2026-05-25 13:33:22,234 [INFO] [CpuWorker] Current Load: 6.06%
2026-05-25 13:33:22,657 [INFO] [MemoryWorker] Current Heap: 75MB
2026-05-25 13:33:24,339 [INFO] [CpuWorker] Cooldown complete (5.00%). Resuming load increase...
2026-05-25 13:33:25,341 [INFO] [CpuWorker] Current Load: 5.00%
2026-05-25 13:33:25,697 [INFO] [MemoryWorker] Current Heap: 100MB
2026-05-25 13:33:27,446 [INFO] [CpuWorker] Peak reached (10.00%). Starting cooldown...
2026-05-25 13:33:28,447 [INFO] [CpuWorker] Current Load: 10.00%
2026-05-25 13:33:28,738 [INFO] [MemoryWorker] Current Heap: 125MB
2026-05-25 13:33:31,552 [INFO] [CpuWorker] Current Load: 9.48%
2026-05-25 13:33:31,775 [INFO] [MemoryWorker] Current Heap: 150MB
2026-05-25 13:33:33,656 [INFO] [CpuWorker] Cooldown complete (5.00%). Resuming load increase...
2026-05-25 13:33:34,661 [INFO] [CpuWorker] Current Load: 5.00%
2026-05-25 13:33:34,779 [INFO] [MemoryWorker] Current Heap: 175MB
2026-05-25 13:33:37,766 [INFO] [CpuWorker] Current Load: 8.97%
2026-05-25 13:33:37,804 [INFO] [MemoryWorker] Current Heap: 200MB
2026-05-25 13:33:39,870 [INFO] [CpuWorker] Peak reached (10.00%). Starting cooldown...
2026-05-25 13:33:40,844 [INFO] [MemoryWorker] Current Heap: 225MB
2026-05-25 13:33:40,871 [INFO] [CpuWorker] Current Load: 10.00%
2026-05-25 13:33:43,886 [INFO] [MemoryWorker] Current Heap: 250MB
2026-05-25 13:33:43,973 [INFO] [CpuWorker] Current Load: 8.67%
^C2026-05-25 13:33:45,325 [INFO] User interrupted process. Shutting down gracefully...
```
<br>

2차 시도 (CPU_MAX_OCCUPY = 95)
```bash
agent-admin@c37974f555e9:~$ export MULTI_THREAD_ENABLE=0
agent-admin@c37974f555e9:~$ export CPU_MAX_OCCUPY=95
agent-admin@c37974f555e9:~$ /usr/local/bin/agent-app-leak
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
   ... MEMORY_LIMIT=512MB, CPU_MAX_OCCUPY=95%, MULTI_THREAD_ENABLE=False
------------------------------------------------------------
All Boot Checks Passed!
Agent READY
2026-05-25 14:14:14,387 [INFO] [SafetyGuard] Process priority lowered (nice=10).
2026-05-25 14:14:14,388 [INFO] Agent listening at port 15034

==================================================
 [ Agent Initiate ] Resource Check 
==================================================
 [ MEMORY ] Limit: 512MB 		[ OK ]
 [ CPU    ] Limit: 95%  		[ WARNING: Recommend Under 50% ]
 [ THREAD ] Concurrency: False 		[ OK ]
--------------------------------------------------
 >>> SYSTEM STATUS: STABLE. STARTING WORKLOAD MONITORING...
==================================================

2026-05-25 14:14:16,389 [INFO] [CpuWorker] Started. Maximum CPU Limit: 95%
2026-05-25 14:14:16,390 [INFO] [CpuWorker] Current Load: 5.00%
2026-05-25 14:14:19,495 [INFO] [CpuWorker] Current Load: 11.96%
2026-05-25 14:14:22,601 [INFO] [CpuWorker] Current Load: 14.76%
2026-05-25 14:14:25,707 [INFO] [CpuWorker] Current Load: 16.52%
2026-05-25 14:14:28,812 [INFO] [CpuWorker] Current Load: 21.84%
2026-05-25 14:14:31,917 [INFO] [CpuWorker] Current Load: 30.88%
2026-05-25 14:14:35,023 [INFO] [CpuWorker] Current Load: 34.50%
2026-05-25 14:14:38,128 [INFO] [CpuWorker] Current Load: 44.40%
2026-05-25 14:14:41,233 [INFO] [CpuWorker] Current Load: 44.92%
2026-05-25 14:14:44,337 [INFO] [CpuWorker] Current Load: 48.90%
2026-05-25 14:14:47,442 [INFO] [CpuWorker] Current Load: 58.42%
2026-05-25 14:14:47,544 [CRITICAL] [CpuWorker] CPU Threshold Violated! (58.42%).

>>> [SYSTEM] WATCHDOG: INITIATING EMERGENCY ABORT (SIGTERM) <<<

Terminated
```
<br>

#### 2-2-2. [Bug] CPU 과점유에 의한 Watchdog 보호 조치 프로세스 강제 종료
##### 1. Description (현상 설명)
단일 스레드 모드(MULTI_THREAD_ENABLE=False) 상태에서 CPU_MAX_OCCUPY=95 설정을 적용하고 agent-app-leak을 실행한 결과,
내부 부하가 선형적으로 상승하였으며, CPU 점유율이 CPU Threshold를 초과한 순간 
WATCHDOG: INITIATING EMERGENCY ABORT (SIGTERM) 메시지를 출력하며 프로세스가 강제 종료(Terminated)되었음 

##### 2. Evidence & Logs (증거 자료)
프로그램 실행 로그
```bash
2026-05-25 14:14:16,389 [INFO] [CpuWorker] Started. Maximum CPU Limit: 95%
2026-05-25 14:14:16,390 [INFO] [CpuWorker] Current Load: 5.00%
2026-05-25 14:14:19,495 [INFO] [CpuWorker] Current Load: 11.96%
2026-05-25 14:14:22,601 [INFO] [CpuWorker] Current Load: 14.76%
2026-05-25 14:14:25,707 [INFO] [CpuWorker] Current Load: 16.52%
2026-05-25 14:14:28,812 [INFO] [CpuWorker] Current Load: 21.84%
2026-05-25 14:14:31,917 [INFO] [CpuWorker] Current Load: 30.88%
2026-05-25 14:14:35,023 [INFO] [CpuWorker] Current Load: 34.50%
2026-05-25 14:14:38,128 [INFO] [CpuWorker] Current Load: 44.40%
2026-05-25 14:14:41,233 [INFO] [CpuWorker] Current Load: 44.92%
2026-05-25 14:14:44,337 [INFO] [CpuWorker] Current Load: 48.90%
2026-05-25 14:14:47,442 [INFO] [CpuWorker] Current Load: 58.42%
2026-05-25 14:14:47,544 [CRITICAL] [CpuWorker] CPU Threshold Violated! (58.42%).

>>> [SYSTEM] WATCHDOG: INITIATING EMERGENCY ABORT (SIGTERM) <<<

Terminated
```

<br>

관제 모니터링 시스템(monitor.sh) 수집 로그
```bash
agent-admin@c37974f555e9:~$ /home/agent-admin/agent-app/bin/monitor.sh
========================================
Monitor Start: 2026-05-25 15:27:08
Target Process: agent-app-leak
========================================
[2026-05-25 15:27:08] PROCESS:agent-app-leak STATUS:NOT_FOUND
[2026-05-25 15:27:11] PID:27246 CPU:4.6% MEM:0.0% RSS:2172KB
[2026-05-25 15:27:15] PID:27246 CPU:2.1% MEM:0.0% RSS:2172KB
[2026-05-25 15:27:18] PID:27246 CPU:1.3% MEM:0.0% RSS:2172KB
[2026-05-25 15:27:21] PID:27246 CPU:1.0% MEM:0.0% RSS:2172KB
[2026-05-25 15:27:24] PID:27246 CPU:0.8% MEM:0.0% RSS:2172KB
[2026-05-25 15:27:27] PID:27246 CPU:0.6% MEM:0.0% RSS:2172KB
[2026-05-25 15:27:30] PID:27246 CPU:0.5% MEM:0.0% RSS:2172KB
[2026-05-25 15:27:33] PID:27246 CPU:0.5% MEM:0.0% RSS:2172KB
[2026-05-25 15:27:36] PID:27246 CPU:0.4% MEM:0.0% RSS:2172KB
[2026-05-25 15:27:39] PID:27246 CPU:0.4% MEM:0.0% RSS:2172KB
[2026-05-25 15:27:42] PROCESS:agent-app-leak STATUS:NOT_FOUND
[2026-05-25 15:27:45] PROCESS:agent-app-leak STATUS:NOT_FOUND
```

<br>

```bash
agent-admin@c37974f555e9:~$ top -bn1 | grep agent
     18 agent-a+  20   0    5024    696      4 S   0.0   0.0   0:00.00 bash
  27058 agent-a+  20   0    5024   2836   2160 S   0.0   0.0   0:00.01 bash
  27753 agent-a+  20   0    5024   3048   2364 S   0.0   0.0   0:00.00 bash
  28075 agent-a+  20   0    2904   2140   1904 S   0.0   0.0   0:00.09 agent-a+
  28076 agent-a+  30  10   27092  21628  11788 S   0.0   0.1   0:00.17 agent-a+
  28079 agent-a+  20   0    9288   5320   3164 R   0.0   0.0   0:00.00 top
  28080 agent-a+  20   0    3964   2316   2128 S   0.0   0.0   0:00.00 grep

agent-admin@c37974f555e9:~$ ps aux | grep agent-app
agent-a+   28075  0.2  0.0   2904  2140 pts/2    S+   15:55   0:00 /usr/local/bin/agent-app-leak
agent-a+   28076  0.8  0.1  27092 18960 pts/2    SN+  15:55   0:00 /usr/local/bin/agent-app-leak
agent-a+   28082  0.0  0.0   4096  2164 pts/3    S+   15:56   0:00 grep --color=auto agent-app 

op - 16:00:54 up  7:42,  0 user,  load average: 0.00, 0.00, 0.00
Tasks:   0 total,   0 running,   0 sleeping,   0 stopped,   0 zombie
%Cpu(s):  0.0 us,  0.0 sy,  0.0 ni,100.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
MiB Mem :  16049.5 total,  15518.2 free,    606.2 used,    189.6 buff/cache    
MiB Swap:  17073.5 total,  17073.5 free,      0.0 used.  15443.3 avail Mem 
```
<br>

##### 3. Root Cause Analysis (원인 분석)
CPU 부하가 내부 Watchdog 임계치를 초과한 원인 분석 <br>
CpuWorker가 시스템 전체 CPU 부하를 지속적으로 상승시키도록 설계되어 있고 <br>
설정된 임계값(CPU_MAX_OCCUPY=95%)보다 낮은 50% 시점에서 Watchdog이 SIGTERM을 발생시켜 프로세스를 강제 종료함  <br>

<br>

##### 4. Workarund & Verification (조치 및 검증)
CPU_MAX_OCCUPY = 10으로 설정했더니 프로세스가 내부 스케줄링 지연(Latency)을 겪기 전에 안전하게 쿨다운 루틴에 진입함 <br>

<br>

### 2-3. Deadlock
#### 2-3-1. 실행 로그 

싱글 스레드 모드 
```bash 
agent-admin@c37974f555e9:~$ export MULTI_THREAD_ENABLE=0
agent-admin@c37974f555e9:~$ export MEMORY_LIMIT=512
agent-admin@c37974f555e9:~$ /usr/local/bin/agent-app-leak
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
   ... MEMORY_LIMIT=512MB, CPU_MAX_OCCUPY=20%, MULTI_THREAD_ENABLE=False
------------------------------------------------------------
All Boot Checks Passed!
Agent READY
2026-05-25 11:13:34,929 [INFO] [SafetyGuard] Process priority lowered (nice=10).
2026-05-25 11:13:34,929 [INFO] Agent listening at port 15034

==================================================
 [ Agent Initiate ] Resource Check 
==================================================
 [ MEMORY ] Limit: 512MB 		[ OK ]
 [ CPU    ] Limit: 20%  		[ OK ]
 [ THREAD ] Concurrency: False 		[ OK ]
--------------------------------------------------
 >>> SYSTEM STATUS: STABLE. STARTING WORKLOAD MONITORING...
==================================================

2026-05-25 11:13:36,932 [INFO] >>> Scenario Selected: [Healthy System Monitoring]

>>> [SYSTEM] ALL CONFIGURATIONS OPTIMAL. RUNNING STABILITY TEST... <<<

2026-05-25 11:13:36,932 [INFO] [Scheduler] Task Scheduler Initialized.
2026-05-25 11:13:36,933 [INFO] [Scheduler] Registered Tasks: ['Thread-A', 'Thread-B', 'Thread-C']
2026-05-25 11:13:36,933 [INFO] [Scheduler] Starting task execution...
2026-05-25 11:13:36,933 [INFO] [Thread-A] Task Started. Calculating... (20%)
2026-05-25 11:13:36,984 [INFO] [Thread-A] Calculating... (40%)
2026-05-25 11:13:37,035 [INFO] [Thread-A] Calculating... (60%)
2026-05-25 11:13:37,086 [INFO] [Thread-A] Calculating... (80%)
2026-05-25 11:13:37,136 [INFO] [Thread-A] Task Completed. (100%)
2026-05-25 11:13:37,187 [INFO] [Thread-B] Task Started. Calculating... (20%)
2026-05-25 11:13:37,239 [INFO] [Thread-B] Calculating... (40%)
2026-05-25 11:13:37,290 [INFO] [Thread-B] Calculating... (60%)
2026-05-25 11:13:37,341 [INFO] [Thread-B] Calculating... (80%)
2026-05-25 11:13:37,393 [INFO] [Thread-B] Task Completed. (100%)
2026-05-25 11:13:37,445 [INFO] [Thread-C] Task Started. Calculating... (20%)
2026-05-25 11:13:37,496 [INFO] [Thread-C] Calculating... (40%)
2026-05-25 11:13:37,548 [INFO] [Thread-C] Calculating... (60%)
2026-05-25 11:13:37,600 [INFO] [Thread-C] Calculating... (80%)
2026-05-25 11:13:37,651 [INFO] [Thread-C] Task Completed. (100%)
2026-05-25 11:13:37,701 [INFO] [Scheduler] All tasks completed.
2026-05-25 11:13:37,729 [INFO] [MemoryWorker] Current Heap: 25MB
2026-05-25 11:13:37,729 [INFO] [CpuWorker] Started. Maximum CPU Limit: 20%
2026-05-25 11:13:37,729 [INFO] [CpuWorker] Current Load: 5.00%
2026-05-25 11:13:40,771 [INFO] [MemoryWorker] Current Heap: 50MB
2026-05-25 11:13:40,834 [INFO] [CpuWorker] Current Load: 8.81%
2026-05-25 11:13:43,809 [INFO] [MemoryWorker] Current Heap: 75MB
2026-05-25 11:13:43,936 [INFO] [CpuWorker] Current Load: 12.27%
2026-05-25 11:13:46,849 [INFO] [MemoryWorker] Current Heap: 100MB
2026-05-25 11:13:47,043 [INFO] [CpuWorker] Current Load: 12.91%
2026-05-25 11:13:49,890 [INFO] [MemoryWorker] Current Heap: 125MB
2026-05-25 11:13:50,148 [INFO] [CpuWorker] Current Load: 18.54%
2026-05-25 11:13:52,251 [INFO] [CpuWorker] Peak reached (20.00%). Starting cooldown...
2026-05-25 11:13:52,930 [INFO] [MemoryWorker] Current Heap: 150MB
2026-05-25 11:13:53,253 [INFO] [CpuWorker] Current Load: 20.00%
2026-05-25 11:13:55,969 [INFO] [MemoryWorker] Current Heap: 175MB
2026-05-25 11:13:56,359 [INFO] [CpuWorker] Current Load: 17.60%
2026-05-25 11:13:59,009 [INFO] [MemoryWorker] Current Heap: 200MB
2026-05-25 11:13:59,465 [INFO] [CpuWorker] Current Load: 16.33%
2026-05-25 11:14:02,050 [INFO] [MemoryWorker] Current Heap: 225MB
2026-05-25 11:14:02,570 [INFO] [CpuWorker] Current Load: 13.67%
2026-05-25 11:14:05,057 [INFO] [MemoryWorker] Current Heap: 250MB
2026-05-25 11:14:05,675 [INFO] [CpuWorker] Current Load: 9.63%
2026-05-25 11:14:08,064 [INFO] [MemoryWorker] Current Heap: 275MB
2026-05-25 11:14:08,781 [INFO] [CpuWorker] Current Load: 6.65%
2026-05-25 11:14:10,885 [INFO] [CpuWorker] Cooldown complete (5.00%). Resuming load increase...
2026-05-25 11:14:11,072 [INFO] [MemoryWorker] Current Heap: 300MB
2026-05-25 11:14:11,886 [INFO] [CpuWorker] Current Load: 5.00%
2026-05-25 11:14:14,106 [INFO] [MemoryWorker] Current Heap: 325MB
2026-05-25 11:14:14,992 [INFO] [CpuWorker] Current Load: 6.53%
2026-05-25 11:14:17,146 [INFO] [MemoryWorker] Current Heap: 350MB
2026-05-25 11:14:18,098 [INFO] [CpuWorker] Current Load: 14.77%
2026-05-25 11:14:20,187 [INFO] [MemoryWorker] Current Heap: 375MB
2026-05-25 11:14:20,200 [INFO] [CpuWorker] Peak reached (20.00%). Starting cooldown...
2026-05-25 11:14:21,201 [INFO] [CpuWorker] Current Load: 20.00%
2026-05-25 11:14:23,223 [INFO] [MemoryWorker] Current Heap: 400MB
2026-05-25 11:14:24,306 [INFO] [CpuWorker] Current Load: 19.82%
2026-05-25 11:14:26,263 [INFO] [MemoryWorker] Current Heap: 425MB
2026-05-25 11:14:27,411 [INFO] [CpuWorker] Current Load: 10.87%
2026-05-25 11:14:29,303 [INFO] [MemoryWorker] Current Heap: 450MB
2026-05-25 11:14:30,517 [INFO] [CpuWorker] Current Load: 6.24%
2026-05-25 11:14:32,343 [INFO] [MemoryWorker] Current Heap: 475MB
2026-05-25 11:14:32,621 [INFO] [CpuWorker] Cooldown complete (5.00%). Resuming load increase...
2026-05-25 11:14:33,623 [INFO] [CpuWorker] Current Load: 5.00%
2026-05-25 11:14:35,385 [INFO] [MemoryWorker] Current Heap: 500MB
2026-05-25 11:14:36,728 [INFO] [CpuWorker] Current Load: 5.07%
2026-05-25 11:14:38,424 [INFO] [MemoryWorker] Current Heap: 525MB
2026-05-25 11:14:38,425 [WARNING] [MemoryWorker] Memory Usage Reached Limit (525MB). Starting cleanup...
2026-05-25 11:14:38,434 [INFO] [System] Memory Cache Flushed. Process Stabilized.

>>> [SYSTEM] MEMORY RECOVERED (Cache Cleared) <<<

2026-05-25 11:14:39,834 [INFO] [CpuWorker] Current Load: 6.60%
2026-05-25 11:14:42,940 [INFO] [CpuWorker] Current Load: 11.52%
2026-05-25 11:14:43,442 [INFO] [MemoryWorker] Current Heap: 25MB
2026-05-25 11:14:46,046 [INFO] [CpuWorker] Current Load: 18.32%
2026-05-25 11:14:46,451 [INFO] [MemoryWorker] Current Heap: 50MB
2026-05-25 11:14:48,151 [INFO] [CpuWorker] Peak reached (20.00%). Starting cooldown...
2026-05-25 11:14:49,152 [INFO] [CpuWorker] Current Load: 20.00%
2026-05-25 11:14:49,460 [INFO] [MemoryWorker] Current Heap: 75MB
2026-05-25 11:14:52,258 [INFO] [CpuWorker] Current Load: 18.22%
2026-05-25 11:14:52,468 [INFO] [MemoryWorker] Current Heap: 100MB
2026-05-25 11:14:55,363 [INFO] [CpuWorker] Current Load: 12.16%
2026-05-25 11:14:55,509 [INFO] [MemoryWorker] Current Heap: 125MB
2026-05-25 11:14:57,467 [INFO] [CpuWorker] Cooldown complete (5.00%). Resuming load increase...
```
<br>

멀티 스레드 모드 
```bash 
agent-admin@c37974f555e9:~$ export MEMORY_LIMIT=512
agent-admin@c37974f555e9:~$ /usr/local/bin/agent-app-leak
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
   ... MEMORY_LIMIT=512MB, CPU_MAX_OCCUPY=20%, MULTI_THREAD_ENABLE=True
------------------------------------------------------------
All Boot Checks Passed!
Agent READY
2026-05-25 09:20:22,858 [INFO] [SafetyGuard] Process priority lowered (nice=10).
2026-05-25 09:20:22,859 [INFO] Agent listening at port 15034

==================================================
 [ Agent Initiate ] Resource Check 
==================================================
 [ MEMORY ] Limit: 512MB 		[ OK ]
 [ CPU    ] Limit: 20%  		[ OK ]
 [ THREAD ] Concurrency: True 		[ WARNING ]
--------------------------------------------------
 >>> SYSTEM WARNING: POTENTIAL DEADLOCK IN CONCURRENT MODE.
==================================================

2026-05-25 09:20:24,861 [WARNING] [AgentWorker] Initializing concurrent transaction processors...
2026-05-25 09:20:24,861 [WARNING] [System] CAUTION: Strict resource locking is enabled.
2026-05-25 09:20:29,863 [INFO] [Worker-Thread-1] Process Started. Attempting to lock [Shared_Memory_A]...
2026-05-25 09:20:29,864 [INFO] [AgentWorker][Worker-Thread-1] LOCK ACQUIRED: [Shared_Memory_A]. (Holding...)
2026-05-25 09:20:29,864 [INFO] [AgentWorker][Worker-Thread-1] Processing critical data in Memory A...
2026-05-25 09:20:29,864 [INFO] [AgentWorker][Worker-Thread-2] Process Started. Attempting to lock [Socket_Pool_B]...
2026-05-25 09:20:29,865 [INFO] [AgentWorker][Worker-Thread-2] LOCK ACQUIRED: [Socket_Pool_B]. (Holding...)
2026-05-25 09:20:29,865 [INFO] [AgentWorker][Worker-Thread-2] Establishing network connections in Pool B...
2026-05-25 09:20:29,865 [INFO] [AgentWorker] Waiting for worker threads to complete transactions...
2026-05-25 09:20:31,866 [INFO] [AgentWorker][Worker-Thread-1] Need resource [Socket_Pool_B] to finish job.
2026-05-25 09:20:31,866 [INFO] [AgentWorker][Worker-Thread-1] WAITING for [Socket_Pool_B]... (Status: BLOCKED)
2026-05-25 09:20:31,867 [INFO] [AgentWorker][Worker-Thread-2] Need resource [Shared_Memory_A] to write logs.
2026-05-25 09:20:31,867 [INFO] [AgentWorker][Worker-Thread-2] WAITING for [Shared_Memory_A]... (Status: BLOCKED)
^C2026-05-25 09:51:55,579 [INFO] User interrupted process. Shutting down gracefully...
```
<br>

#### 2-3-2. [Bug] 멀티스레드 환경에서 교착상태 (Deadlock) 발생으로 프로세스 무응답
##### 1. Description (현상 설명)
MULTI_THREAD_ENABLE=True 환경에서 agent-app-leak 어플리케이션을 실행하면, <br>
부트 체크 단계 통과 후 트랜잭션 처리 과정에서 프로세스가 강제 종료되지 않고 PID는 유지되나, <br>
로그 출력이 완전히 멈추고 외부 요청에 응답하지 않는 무응답(Hang) 상태가 지속됨 <br>
사용자가 터미널에서 ^C(Ctrl+C)를 통해 수동으로 프로세스를 인터럽트하기 전까지 시스템이 영원히 대기 상태에 머물고 있음 <br>
<br>

##### 2. Evidence & Logs (증거 자료)

프로세스가 시작된 후 Worker-Thread-1과 Worker-Thread-2가 각각 자원을 선점한 상태에서, 서로의 자원을 요청하며 BLOCKED 상태로 무한 대기하는 교착상태 패턴을 보임 
<br>

```bash
ps -ef | grep agent
root          46       1  0 09:17 pts/0    00:00:00 su - agent-admin
agent-a+      47      46  0 09:17 pts/0    00:00:00 -bash
agent-a+      67      47  0 10:09 pts/0    00:00:00 /usr/local/bin/agent-app-leak   # 부모 PID(PPID)가 47인 자식 프로세스 67번 실행
agent-a+      68      67  0 10:09 pts/0    00:00:00 /usr/local/bin/agent-app-leak   # 부모 PID(PPID)가 67인 자식 프로세스(스레드) 68번 생성
agent-a+      71      47  0 10:09 pts/0    00:00:00 ps -ef
agent-a+      72      47  0 10:09 pts/0    00:00:00 grep --color=auto agent
```

ps -ef | grep agent 결과 : <br>
부모 프로세스(PID: 67)가 로직 및 멀티스레드 처리를 위해 자식 프로세스(PID : 68)를 생성 <br>
<br>

```bash
agent-admin@c37974f555e9:~$ ps -fL -p 67
UID          PID    PPID     LWP  C NLWP STIME TTY          TIME CMD
agent-a+      67      47      67  0    1 10:09 pts/0    00:00:00 /usr/local/bin/agent-app-lea
```

```bash
agent-admin@c37974f555e9:~$ ps -fL -p 68
UID          PID    PPID     LWP  C NLWP STIME TTY          TIME CMD
agent-a+      68      67      68  0    3 10:09 pts/0    00:00:00 /usr/local/bin/agent-app-lea
agent-a+      68      67      69  0    3 10:09 pts/0    00:00:00 /usr/local/bin/agent-app-lea
agent-a+      68      67      70  0    3 10:09 pts/0    00:00:00 /usr/local/bin/agent-app-lea
```

PID 68번 내부에서 총 3개의 프로세스/스레드(LWP 68, 69, 70)가 생성됨 <br>
CPU 사용 시간(TIME)이 00:00:00 -> 스레드들이 작업을 진행하지 못하고 대기 상태(Sleep/Blocked)에 갇혀 있음 <br>
<br>

구조 
```bash
[PID: 47] bash (할아버지)
       │
[PID: 67] agent-app-leak 메인 프로세스 (부모)
       │
       └─► [PID: 68] 자식 프로세스 
                │
                ├─► [LWP: 68] 메인 스레드 (실제 69, 70을 생성한 주체)
                ├─► [LWP: 69] 서브 스레드 1
                └─► [LWP: 70] 서브 스레드 2
```
<br>

top -H 명령어를 통한 스레드별 자원 점유율 확인
<p>
   <img width="630" height="230" alt="Screenshot 2026-05-25 at 10 10 42 AM" src="https://github.com/user-attachments/assets/fc9ad8c0-0a82-4ea7-ab1a-b4fd288bae0c" />
</p>
<br>

- 핵심 스레드들(PID/LWP: 68, 69, 70)의 상태 코드가 모두 S (Sleeping/Blocked) 상태로 갇혀 있음 
- 현재 실행 중인 스레드는 top 명령어 자신(PID 73, R)이 유일
- 애플리케이션이 실행 중이지만, 작업을 처리해야 할 스레드 68, 69, 70번의 %CPU 수치가 모두 0.0임 -> 연산 작업을 전혀 수행하지 못하고 락(Lock) 해제만을 기다리며 멈춰 있음을 뜻함 
- CPU 누적 시간(TIME+) 정지 -> 각 스레드가 생성된 이후 소비한 총 CPU 시간(TIME+)이 0:00.05, 0:00.00 등으로 극히 낮게 멈춰 있음. 시스템 루프가 정상적으로 돌지 못하고 초기 진입 단계에서 바로 데드락이 발생했다는 것을 알 수 있음 
<br>

##### 3. Root Cause Analysis (원인 분석)
```bash
2026-05-25 09:20:24,861 [WARNING] [AgentWorker] Initializing concurrent transaction processors...
2026-05-25 09:20:24,861 [WARNING] [System] CAUTION: Strict resource locking is enabled.
2026-05-25 09:20:29,863 [INFO] [Worker-Thread-1] Process Started. Attempting to lock [Shared_Memory_A]...

# Worker-Thread-1이 Shared_Memory_A 자원의 락(Lock)을 획득하고, Worker-Thread-2가 Socket_Pool_B 자원의 락(Lock)을 획득함
2026-05-25 09:20:29,864 [INFO] [AgentWorker][Worker-Thread-1] LOCK ACQUIRED: [Shared_Memory_A]. (Holding...)
2026-05-25 09:20:29,864 [INFO] [AgentWorker][Worker-Thread-1] Processing critical data in Memory A...
2026-05-25 09:20:29,864 [INFO] [AgentWorker][Worker-Thread-2] Process Started. Attempting to lock [Socket_Pool_B]...
2026-05-25 09:20:29,865 [INFO] [AgentWorker][Worker-Thread-2] LOCK ACQUIRED: [Socket_Pool_B]. (Holding...)
2026-05-25 09:20:29,865 [INFO] [AgentWorker][Worker-Thread-2] Establishing network connections in Pool B...
2026-05-25 09:20:29,865 [INFO] [AgentWorker] Waiting for worker threads to complete transactions...

# Worker-Thread-1은 다음 작업을 위해 Socket_Pool_B를 요청하지만, 이미 Thread-2가 쥐고 있으므로 BLOCKED 상태가 됨
2026-05-25 09:20:31,866 [INFO] [AgentWorker][Worker-Thread-1] Need resource [Socket_Pool_B] to finish job.
2026-05-25 09:20:31,866 [INFO] [AgentWorker][Worker-Thread-1] WAITING for [Socket_Pool_B]... (Status: BLOCKED)

# Worker-Thread-2는 로그 기록을 위해 Shared_Memory_A를 요청하지만, 이미 Thread-1이 쥐고 있으므로 BLOCKED 상태가 됨
2026-05-25 09:20:31,867 [INFO] [AgentWorker][Worker-Thread-2] Need resource [Shared_Memory_A] to write logs.
2026-05-25 09:20:31,867 [INFO] [AgentWorker][Worker-Thread-2] WAITING for [Shared_Memory_A]... (Status: BLOCKED)
```

데드락 발생 4대 조건 성립 여부
- 상호 배제(Mutual Exclusion): Strict resource locking이 활성화되어 한 번에 한 스레드만 자원을 점유 가능
- 점유 및 대기(Hold and Wait): 각 스레드가 자원(Memory_A, Pool_B)을 붙잡은 채(Holding) 상대방의 자원을 대기함
- 비선점(No Preemption): 상대방 스레드가 가진 자원을 강제로 뺏어올 수 없음
- 순환 대기(Circular Wait): Thread-1은 Thread-2의 자원을, Thread-2는 Thread-1의 자원을 서로 기다리는 고리가 형성됨 
<br>

##### 4. Workaround & Verification (조치 및 검증)
MULTI_THREAD_ENABLE=False로 설정하여 단일 스레드 방식으로 동작하게 함 (자원 경쟁 및 순환 대기가 발생하지 않도록) <br>
그 결과, 태스크 스케줄러가 등록된 작업들(Thread-A, Thread-B, Thread-C)을 순차적으로 호출하여 모두 안전하게 완료(100% Task Completed)함 <br>
Heap 메모리가 설정된 임계치 부근인 525MB까지 상승했으나, 애플리케이션 내부 메모리 보호 정책 [MemoryWorker]이 정상 작동하여 <br>
Memory Usage Reached Limit. Starting cleanup... 로그와 함께 캐시를 비워냄(Current Heap을 25MB로) <br>
<br>

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

root@c37974f555e9:/# source /etc/bash.bashrc
```
<br>       

secret.key 생성
```bash
root@c37974f555e9:/# echo "agent_api_key_test" > /home/agent-admin/agent-app/api_keys/secret.key
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

## 4. 개념 알아가기 
### 4-1. PID와 LWP
PID (Process ID): 프로세스 그룹의 대표 번호 (Thread Group ID)
LWP (Light Weight Process ID): 개별 스레드의 고유 번호

- 리눅스 규칙: 어떤 프로세스가 처음 실행되면, 그 프로세스의 메인 스레드가 생성됨. 이때 메인 스레드의 LWP 번호는 PID 번호와 똑같이 할당됨 
<br>

```bash
UID          PID    PPID     LWP  C NLWP STIME TTY          TIME CMD
agent-a+      68      67      68  0    3 10:09 pts/0    00:00:00 /usr/local/bin/agent-app-lea
agent-a+      68      67      69  0    3 10:09 pts/0    00:00:00 /usr/local/bin/agent-app-lea
agent-a+      68      67      70  0    3 10:09 pts/0    00:00:00 /usr/local/bin/agent-app-lea
```

LWP 68번 스레드: 자신의 PID(68)와 LWP(68) 번호가 일치 -> PID 68번 프로세스의 메인 스레드 <br>
LWP 69, 70번 스레드: PID는 68이지만 LWP 번호가 다름 -> PID 68번이라는 울타리(프로세스) 안에서 살고 있는 서브 스레드들 <br>
<br>
<br>

> **왜 PPID는 모두 67?** <br>
<br>

리눅스에서 스레드들은 메모리와 자원을 공유하는 하나의 공동체(프로세스)임 <br>
자식 스레드(69, 70)를 생성한 주체는 메인 스레드(68)가 맞지만, 리눅스 커널은 이 스레드 집단 전체를 하나의 프로세스(PID 68)로 묶어서 관리함 <br>
그리고 이 프로세스 집단을 통째로 낳아준 실제 부모 프로세스는 67번임 <br>
따라서 69번, 70번 스레드 입장에서 '나를 생성한 부모 스레드'는 68번이 맞지만, 시스템 관리 차원에서 '너희 스레드 집단(PID 68)을 태어나게 해준 부모 프로세스(PPID)'는 67임 <br>
