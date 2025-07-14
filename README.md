# Kubernetes 高可用性叢集 Ansible Playbook

基於 Kubernetes v1.32 的完整自動化部署方案，使用 kube-vip 實現控制平面高可用

## 功能特點

- 自動化部署 3 個 Master 節點的高可用叢集
- **kube-vip** 提供控制平面 VIP 高可用
- **Containerd** 容器運行時 (手動下載安裝)
- **Calico CNI** 網路插件 (v3.29.4)
- **台灣時區 & chrony 校時**
- 完整的系統初始化和網路配置

## 系統需求

- **OS**: Ubuntu 20.04/22.04 LTS
- **Ansible**: 2.9+ (需要 kubernetes.core collection)
- **SSH**: 無密碼登入配置
- **網路**: 所有節點間可互相通信
- **Python**: 目標節點需安裝 python3

## 叢集架構

```
kube-vip VIP:   10.10.7.236:6443 (API Server 高可用端點)
Master Nodes:   10.10.7.230-232 (Control Plane)
Worker Nodes:   10.10.7.233-234 (Data Plane)
```

## 安裝依賴

```bash
# 安裝 Ansible 和 Kubernetes collection
pip3 install ansible
ansible-galaxy collection install kubernetes.core

# 或使用系統包管理器
sudo apt update
sudo apt install ansible python3-kubernetes
```

## 快速開始

### 1. 修改 inventory.ini

編輯 `inventory.ini` 文件，配置您的伺服器資訊：

```ini
[masters]
master-01 ansible_host=10.10.7.230 hostname=master-01
master-02 ansible_host=10.10.7.231 hostname=master-02
master-03 ansible_host=10.10.7.232 hostname=master-03

[workers]
worker-01 ansible_host=10.10.7.233 hostname=worker-01
worker-02 ansible_host=10.10.7.234 hostname=worker-02

[all:vars]
ansible_user=bbg
ansible_ssh_private_key_file=~/.ssh/id_rsa
ansible_become=yes
ansible_become_pass=1qaz@WSX

# Kubernetes cluster configuration
k8s_version=1.32
control_plane_endpoint=10.10.7.236:6443
pod_network_cidr=10.244.0.0/16
service_cidr=10.96.0.0/12
containerd_version=1.7.27
calico_version=v3.29.4

# kube-vip configuration
kube_vip_ip=10.10.7.236
kube_vip_interface=ens18
```

### 2. 配置 SSH 金鑰

確保從 Ansible 控制節點可以無密碼 SSH 登入所有目標節點：

```bash
# 生成 SSH 金鑰（如果尚未有）
ssh-keygen -t rsa -b 4096

# 複製公鑰到所有節點
ssh-copy-id bbg@10.10.7.230
ssh-copy-id bbg@10.10.7.231
ssh-copy-id bbg@10.10.7.232
ssh-copy-id bbg@10.10.7.233
ssh-copy-id bbg@10.10.7.234
```

### 3. 執行部署

```bash
# 使用部署腳本（推薦）
./deploy.sh

# 或直接執行 Ansible Playbook
ansible-playbook -i inventory.ini k8s-cluster.yml

# 檢查連通性
ansible -i inventory.ini all -m ping
```

## 檔案結構

```
├── inventory.ini               # 伺服器清單配置
├── k8s-cluster.yml            # 主要 Playbook
├── deploy.sh                  # 部署腳本
├── tasks/                     # 任務模組
│   ├── 01-system-setup.yml      # 系統設定 (時區、chrony、swap、網路)
│   ├── 02-containerd.yml        # Containerd + runc + CNI 安裝
│   ├── 03-kubernetes.yml        # Kubernetes 套件安裝
│   ├── 04-haproxy.yml           # HAProxy 配置 (可選)
│   ├── 05-cluster-init.yml      # 集群初始化
│   ├── 06-master-join.yml       # Master 節點加入
│   ├── 07-worker-join.yml       # Worker 節點加入
│   ├── 08-cni-install.yml       # CNI 插件 (已廢棄)
│   ├── 09-kube-vip-setup.yml    # kube-vip 配置
│   ├── 10-kubeadm-init-config.yml # kubeadm 配置文件
│   ├── 11-calico-install.yml    # Calico CNI 安裝
│   └── 12-node-labels.yml       # 節點標籤設定
└── README.md
```

## 部署流程

1. **系統準備** - 時區、chrony、swap、網路模組設定
2. **容器運行時** - 下載安裝 containerd、runc、CNI 插件
3. **Kubernetes 套件** - 安裝 kubelet、kubeadm、kubectl
4. **kube-vip 配置** - 在所有 master 節點設定 VIP
5. **集群初始化** - 第一個 master 節點初始化
6. **網路插件** - 部署 Calico CNI
7. **節點加入** - 其他 master 和 worker 節點加入
8. **最終配置** - 節點標籤和 crictl 設定

## 驗證部署

部署完成後，登入任一 Master 節點驗證：

```bash
# 檢查節點狀態
kubectl get nodes -o wide

# 檢查所有 Pod 狀態  
kubectl get pods -A

# 檢查叢集資訊
kubectl cluster-info

# 檢查 kube-vip 狀態
kubectl -n kube-system get lease plndr-cp-lock

# 測試高可用 (關閉一個 master 節點)
kubectl get nodes
```

預期輸出：
```
NAME        STATUS   ROLES           AGE   VERSION
master-01   Ready    control-plane   10m   v1.32.4
master-02   Ready    control-plane   8m    v1.32.4
master-03   Ready    control-plane   6m    v1.32.4
worker-01   Ready    worker          4m    v1.32.4
worker-02   Ready    worker          4m    v1.32.4
```

## 自定義配置

可以在 `inventory.ini` 中修改以下變數：

```ini
[all:vars]
k8s_version=1.32                     # Kubernetes 版本
control_plane_endpoint=10.10.7.236:6443  # kube-vip VIP 端點
pod_network_cidr=10.244.0.0/16      # Pod 網路 CIDR
service_cidr=10.96.0.0/12            # Service 網路 CIDR
containerd_version=1.7.27            # Containerd 版本
calico_version=v3.29.4               # Calico 版本
kube_vip_ip=10.10.7.236             # kube-vip VIP 地址
kube_vip_interface=ens18             # 網卡介面名稱
```

## 故障排除

### 常見問題

1. **SSH 連線失敗**
   ```bash
   # 檢查連通性
   ansible -i inventory.ini all -m ping
   # 檢查 SSH 金鑰
   ssh-add -l
   ```

2. **containerd CRI 錯誤**
   ```bash
   # 檢查 containerd 狀態
   sudo systemctl status containerd
   # 檢查 CRI 配置
   sudo crictl info
   ```

3. **kube-vip VIP 無法訪問**
   ```bash
   # 檢查 kube-vip pod
   kubectl -n kube-system get pods | grep kube-vip
   # 檢查網路介面
   ip addr show ens18
   ```

4. **節點無法加入叢集**
   ```bash
   # 重新生成 join token
   sudo kubeadm token create --print-join-command
   # 檢查時間同步
   timedatectl status
   ```

### 手動檢查

```bash
# 檢查容器運行時
sudo systemctl status containerd
sudo crictl ps

# 檢查 Kubernetes 服務
sudo systemctl status kubelet
sudo journalctl -u kubelet -f

# 檢查網路
sudo systemctl status chrony
ip route show

# 檢查 kube-vip
kubectl -n kube-system logs -l app=kube-vip
```

### 重置集群

如需重新部署：

```bash
# 在所有節點執行
sudo kubeadm reset -f
sudo rm -rf /etc/kubernetes/
sudo rm -rf /var/lib/etcd/
sudo rm -rf ~/.kube/

# 重新執行部署
ansible-playbook -i inventory.ini k8s-cluster.yml
```

## 高可用測試

測試 kube-vip 高可用功能：

```bash
# 1. 檢查當前 VIP 持有者
kubectl -n kube-system get lease plndr-cp-lock

# 2. 關閉持有 VIP 的 master 節點
sudo poweroff

# 3. 從其他節點驗證 VIP 是否切換
kubectl get nodes
kubectl -n kube-system get lease plndr-cp-lock
```

## 安全考量

- 定期更新 join tokens
- 配置 RBAC 權限控制
- 啟用 Pod Security Standards
- 定期備份 etcd 資料
- 使用私鑰文件而非密碼認證

## 維護

### 新增 Worker 節點

1. 在 `inventory.ini` 中添加新節點
2. 執行：`ansible-playbook -i inventory.ini k8s-cluster.yml --limit workers`

### 升級叢集

1. 更新 `k8s_version` 變數
2. 按順序升級各節點（先 master 後 worker）

### 監控

```bash
# 檢查集群健康狀態
kubectl get componentstatuses
kubectl top nodes
kubectl top pods -A
```

## 支援

如有問題，請檢查：
- Ansible 執行日誌
- Kubernetes 事件：`kubectl get events --sort-by='.lastTimestamp'`
- Pod 日誌：`kubectl logs <pod-name> -n <namespace>`
- 系統日誌：`sudo journalctl -u kubelet -f`

## 版本資訊

- Kubernetes: v1.32.4
- Containerd: v1.7.27
- Calico: v3.29.4
- kube-vip: 最新版本
- runc: v1.3.0