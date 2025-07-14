# Kubernetes 高可用性叢集 Ansible Playbook

基於 Kubernetes v1.33 的完整自動化部署方案

## 功能特點

- 自動化部署 3 個 Master 節點的高可用叢集
- HAProxy 負載均衡器配置
- Containerd 容器運行時
- Calico CNI 網路插件
- 完整的系統初始化和配置

## 系統需求

- **OS**: Ubuntu 20.04 LTS
- **Ansible**: 2.9+
- **SSH**: 無密碼登入配置
- **網路**: 所有節點間可互相通信

## 叢集架構

```
Load Balancer:  10.10.7.220 (HAProxy)
Master Nodes:   10.10.7.230-232 (Control Plane)
Worker Nodes:   10.10.7.233-234 (Data Plane)
```

## 快速開始

### 1. 修改 inventory.ini

編輯 `inventory.ini` 文件，配置您的伺服器資訊：

```ini
[loadbalancer]
haproxy-lb ansible_host=10.10.7.220

[masters]
master-01 ansible_host=10.10.7.230 hostname=master-01
master-02 ansible_host=10.10.7.231 hostname=master-02
master-03 ansible_host=10.10.7.232 hostname=master-03

[workers]
worker-01 ansible_host=10.10.7.233 hostname=worker-01
worker-02 ansible_host=10.10.7.234 hostname=worker-02
```

### 2. 配置 SSH 金鑰

確保從 Ansible 控制節點可以無密碼 SSH 登入所有目標節點：

```bash
# 生成 SSH 金鑰（如果尚未有）
ssh-keygen -t rsa -b 4096

# 複製公鑰到所有節點
ssh-copy-id ubuntu@10.10.7.220
ssh-copy-id ubuntu@10.10.7.230
ssh-copy-id ubuntu@10.10.7.231
ssh-copy-id ubuntu@10.10.7.232
ssh-copy-id ubuntu@10.10.7.233
ssh-copy-id ubuntu@10.10.7.234
```

### 3. 執行部署

```bash
# 使用部署腳本（推薦）
./deploy.sh

# 或直接執行 Ansible Playbook
ansible-playbook -i inventory.ini k8s-cluster.yml
```

## 檔案結構

```
├── inventory.ini           # 伺服器清單配置
├── k8s-cluster.yml        # 主要 Playbook
├── deploy.sh              # 部署腳本
├── tasks/                 # 任務模組
│   ├── 01-system-setup.yml
│   ├── 02-containerd.yml
│   ├── 03-kubernetes.yml
│   ├── 04-haproxy.yml
│   ├── 05-cluster-init.yml
│   ├── 06-master-join.yml
│   ├── 07-worker-join.yml
│   └── 08-cni-install.yml
└── README.md
```

## 驗證部署

部署完成後，登入任一 Master 節點驗證：

```bash
# 檢查節點狀態
kubectl get nodes -o wide

# 檢查所有 Pod 狀態
kubectl get pods -A

# 檢查叢集資訊
kubectl cluster-info
```

## 自定義配置

可以在 `inventory.ini` 中修改以下變數：

```ini
[all:vars]
k8s_version=1.33                    # Kubernetes 版本
control_plane_endpoint=10.10.7.220:6443  # 負載均衡器端點
pod_network_cidr=192.168.0.0/16     # Pod 網路 CIDR
service_cidr=10.96.0.0/12           # Service 網路 CIDR
calico_version=v3.27.0              # Calico 版本
```

## 故障排除

### 常見問題

1. **SSH 連線失敗**
   - 檢查 SSH 金鑰配置
   - 確認目標主機可達性
   - 驗證 `ansible_user` 設定

2. **kubeadm 初始化失敗**
   - 檢查防火牆設定
   - 確認容器運行時狀態
   - 驗證網路配置

3. **節點無法加入叢集**
   - 檢查 join token 有效性
   - 確認網路連通性
   - 驗證時間同步

### 手動檢查

```bash
# 檢查 containerd 狀態
sudo systemctl status containerd

# 檢查 kubelet 狀態
sudo systemctl status kubelet

# 檢查 kubeadm 配置
sudo kubeadm config print init-defaults
```

## 安全考量

- 定期更新 join tokens
- 配置 RBAC 權限控制
- 啟用 Pod Security Policies
- 定期備份 etcd 資料

## 維護

### 新增 Worker 節點

1. 在 `inventory.ini` 中添加新節點
2. 執行：`ansible-playbook -i inventory.ini k8s-cluster.yml --limit workers`

### 升級叢集

1. 更新 `k8s_version` 變數
2. 按順序升級各節點

## 支援

如有問題，請檢查：
- Ansible 執行日誌
- Kubernetes 事件：`kubectl get events`
- Pod 日誌：`kubectl logs <pod-name>`