# Kubernetes VirtualBox cluster playbooks

Исходная ссылка: https://disk.yandex.ru/i/8QScRsXM53WRmA

## Структура

- `playbooks/common` - общие проверки, подготовка узлов и очистка перед установкой с нуля.
- `playbooks/singlenode` - fresh install сценарий `master1` + `worker1` + `worker2`.
- `playbooks/multinode` - fresh install сценарий HA: `master1`, `master2`, `master3`, `worker1`, `worker2`.
- `playbooks/_operator` - служебные recovery/remediation сценарии, не входящие в обычный порядок установки.

## Инвентари

- `inventory/singlenode-lan.ini` - 1 master + 2 worker по LAN IP.
- `inventory/singlenode-nat.ini` - 1 master + 2 worker через VirtualBox NAT ports.
- `inventory/multinode-lan.ini` - 3 master + 2 worker по LAN IP.
- `inventory/multinode-nat.ini` - 3 master + 2 worker через VirtualBox NAT ports.

`ansible.cfg` оставлен на старом `inventory/lan.ini`, поэтому инвентарь лучше указывать явно через `-i`.

## Container Runtime

По умолчанию fresh install использует `containerd`. Это меньше нагружает lab-кластер, чем связка Docker + `cri-dockerd`, и является стандартным runtime для Kubernetes.

Если нужно вернуть прежний вариант Docker + `cri-dockerd`, передавайте одну и ту же переменную во все runtime-зависимые playbook-и выбранного сценария:

```bash
-e container_runtime=docker
```

## Диагностика

Посмотреть load average, текущую CPU-нагрузку и память на узлах single-master кластера.

```bash
ansible all -i inventory/singlenode-lan.ini -m shell -a 'hostname; uptime; top -bn1 | head -5'
```

Ansible ad-hoc `shell` может показать `CHANGED`, но эта команда только читает состояние и ничего не меняет.

Проверить SSH/Ansible подключение ко всем узлам inventory.

```bash
ansible all -i inventory/multinode-lan.ini -m ping
```

Для single-master проверки используйте тот же вызов с `inventory/singlenode-lan.ini`.

## Single-Master С Нуля

Полностью очистить `master1`, `worker1`, `worker2` перед новой установкой.

```bash
ansible-playbook -i inventory/singlenode-lan.ini playbooks/common/99-full-cleanup.yaml
```

Проверить сеть и IP/MAC узлов single-master топологии.

```bash
ansible-playbook -i inventory/singlenode-lan.ini playbooks/common/00-network-check.yaml
```

Подготовить `master1`, `worker1`, `worker2`: OS, containerd, kubeadm, kubelet, kubectl. По умолчанию Kubernetes-пакеты берутся с Yandex mirror.

```bash
ansible-playbook -i inventory/singlenode-lan.ini playbooks/common/01-prepare-nodes.yaml
```

Если нужно использовать официальный `pkgs.k8s.io`, переключите источник переменной.

```bash
ansible-playbook -i inventory/singlenode-lan.ini playbooks/common/01-prepare-nodes.yaml -e kubernetes_repo_source=official
```

Если нужен прежний runtime Docker + `cri-dockerd`, подготовку и следующие init/join playbook-и запускайте с `container_runtime=docker`.

```bash
ansible-playbook -i inventory/singlenode-lan.ini playbooks/common/01-prepare-nodes.yaml -e container_runtime=docker
ansible-playbook -i inventory/singlenode-lan.ini playbooks/singlenode/03-init-single-master.yaml -e container_runtime=docker
ansible-playbook -i inventory/singlenode-lan.ini playbooks/singlenode/04-join-workers.yaml -e container_runtime=docker
```

Инициализировать single-master cluster на `master1`.

```bash
ansible-playbook -i inventory/singlenode-lan.ini playbooks/singlenode/03-init-single-master.yaml
```

Подключить `worker1` и `worker2`.

```bash
ansible-playbook -i inventory/singlenode-lan.ini playbooks/singlenode/04-join-workers.yaml
```

Завершить fresh single-master установку: оставить `master1` dedicated control-plane, дождаться worker-ов, настроить один replica CoreDNS.

```bash
ansible-playbook -i inventory/singlenode-lan.ini playbooks/singlenode/05-finalize-single-master.yaml
```

Если нужен настоящий all-in-one режим без worker-ов, init можно запустить с workload-ами на master:

```bash
ansible-playbook -i inventory/singlenode-lan.ini playbooks/singlenode/03-init-single-master.yaml -e allow_workloads_on_master=true
```

## Multinode С Нуля

Полностью очистить `master1`, `master2`, `master3`, `worker1`, `worker2` перед новой установкой.

```bash
ansible-playbook -i inventory/multinode-lan.ini playbooks/common/99-full-cleanup.yaml
```

Проверить сеть и IP/MAC узлов multinode топологии.

```bash
ansible-playbook -i inventory/multinode-lan.ini playbooks/common/00-network-check.yaml
```

Подготовить все master и worker узлы: OS, containerd, kubeadm, kubelet, kubectl. По умолчанию Kubernetes-пакеты берутся с Yandex mirror.

```bash
ansible-playbook -i inventory/multinode-lan.ini playbooks/common/01-prepare-nodes.yaml
```

Если нужно использовать официальный `pkgs.k8s.io`, переключите источник переменной.

```bash
ansible-playbook -i inventory/multinode-lan.ini playbooks/common/01-prepare-nodes.yaml -e kubernetes_repo_source=official
```

Если нужен прежний runtime Docker + `cri-dockerd`, подготовку и следующие init/join playbook-и запускайте с `container_runtime=docker`.

```bash
ansible-playbook -i inventory/multinode-lan.ini playbooks/common/01-prepare-nodes.yaml -e container_runtime=docker
ansible-playbook -i inventory/multinode-lan.ini playbooks/multinode/03-init-cluster.yaml -e container_runtime=docker
ansible-playbook -i inventory/multinode-lan.ini playbooks/multinode/04-join-cluster.yaml -e container_runtime=docker
```

Настроить keepalived VIP на `master1`, `master2`, `master3`.

```bash
ansible-playbook -i inventory/multinode-lan.ini playbooks/multinode/02-keepalived-vip.yaml
```

Инициализировать первый control-plane узел HA-кластера.

```bash
ansible-playbook -i inventory/multinode-lan.ini playbooks/multinode/03-init-cluster.yaml
```

Подключить остальные control-plane и worker узлы к HA-кластеру.

```bash
ansible-playbook -i inventory/multinode-lan.ini playbooks/multinode/04-join-cluster.yaml
```

## Дополнительно

Сбросить только Kubernetes-состояние без удаления пакетов.

```bash
ansible-playbook -i inventory/singlenode-lan.ini playbooks/common/00-reset-k8s-state.yaml
ansible-playbook -i inventory/multinode-lan.ini playbooks/common/00-reset-k8s-state.yaml
```

Если после `99-full-cleanup.yaml` узел завис на reboot и не возвращается по SSH, можно выполнить служебный reset ВМ и дождаться SSH.

```bash
ansible-playbook playbooks/_operator/09-reset-vm-wait-ssh.yaml -e target_vm=worker1 -e target_host=192.168.0.36
```

Остановить процессы, оставшиеся после прерванного playbook-а, и восстановить состояние `dpkg` перед повторным запуском.

```bash
ansible-playbook -i inventory/multinode-lan.ini playbooks/_operator/10-stop-interrupted-playbook-processes.yaml
```

Запустить старый служебный вариант подготовки узлов из `_operator`.

```bash
ansible-playbook -i inventory/multinode-lan.ini playbooks/_operator/01-prepare-nodes.yaml
```

Установить kube-prometheus-stack и Grafana только когда мониторинг действительно нужен.

```bash
ansible-playbook -i inventory/singlenode-lan.ini playbooks/common/05-monitoring.yaml
```

Monitoring не входит в fresh install порядок, потому что он заметно увеличивает нагрузку на lab-кластер.
