# Docker 构建文档

## 使用 SSH 密钥构建 Docker 镜像

由于 Dockerfile 需要从私有 GitHub 仓库克隆代码，构建时需要使用 SSH 密钥进行身份验证。

### 构建命令

```bash
cd /home/admin/project/lightpanda-browser && \
DOCKER_BUILDKIT=1 docker build \
  --ssh default=/home/admin/.ssh/id_ed25519 \
  -t lightpanda-browser .
```

### 命令详解

#### 1. `DOCKER_BUILDKIT=1`
启用 Docker BuildKit 构建引擎。这是使用 SSH 挂载功能的前提条件。

#### 2. `--ssh default=/home/admin/.ssh/id_ed25519`
将宿主机的 SSH 私钥转发给 Docker 构建过程：
- `default` 是 SSH 挂载的标识符，对应 Dockerfile 中的 `--mount=type=ssh`
- `/home/admin/.ssh/id_ed25519` 是私钥的路径
- 密钥仅在构建时临时可用，不会保存在镜像中

#### 3. `-t lightpanda-browser`
为构建的镜像指定标签（名称）。

#### 4. `.`
构建上下文，指定当前目录。

### Dockerfile 修改说明

在 Dockerfile 的第一行添加了 BuildKit 语法声明：
```dockerfile
# syntax=docker/dockerfile:1
```

克隆仓库的命令使用了 SSH 挂载：
```dockerfile
RUN --mount=type=ssh \
    mkdir -p -m 0700 ~/.ssh && \
    ssh-keyscan github.com >> ~/.ssh/known_hosts && \
    git clone git@github.com:lexmount/lightpanda-browser.git
```

### 工作原理

1. **SSH 密钥转发**：
   ```
   宿主机                     Docker BuildKit              容器内部
   ~/.ssh/id_ed25519    ───────────────────→    临时 SSH socket
                              安全转发               (仅在 RUN 期间可用)
                                                          ↓
                                                     git clone
   ```

2. **安全性**：
   - SSH 密钥不会写入任何镜像层
   - 只在特定的 RUN 命令执行时可用
   - 无法从最终镜像中提取密钥
   - 符合最小权限原则

### 使用 ssh-agent（备选方案）

如果你的 ssh-agent 已经运行并加载了密钥：

```bash
# 启动 ssh-agent 并添加密钥
eval $(ssh-agent)
ssh-add /home/admin/.ssh/id_ed25519

# 构建（不需要指定密钥路径）
cd /home/admin/project/lightpanda-browser && \
DOCKER_BUILDKIT=1 docker build --ssh default -t lightpanda-browser .
```

### 运行容器

构建完成后，可以运行容器：

```bash
# 运行并暴露 CDP 端口
docker run -d --name lightpanda -p 9222:9222 lightpanda-browser

# 查看日志
docker logs lightpanda

# 进入容器
docker exec -it lightpanda /bin/bash
```

### 故障排查

#### 错误：Permission denied (publickey)
**原因**：未使用 `--ssh` 参数或密钥路径错误

**解决**：
1. 确保使用 `DOCKER_BUILDKIT=1`
2. 确保使用 `--ssh default=/path/to/key` 参数
3. 验证密钥路径正确且可以访问 GitHub：
   ```bash
   ssh -T git@github.com
   ```

#### 错误：failed to solve with frontend dockerfile.v0
**原因**：未启用 BuildKit 或 Dockerfile 第一行缺少语法声明

**解决**：
1. 确保设置 `DOCKER_BUILDKIT=1`
2. 确保 Dockerfile 第一行是 `# syntax=docker/dockerfile:1`

### 多平台构建

如果需要构建 ARM64 架构的镜像：

```bash
docker buildx build \
  --platform linux/arm64 \
  --ssh default=/home/admin/.ssh/id_ed25519 \
  -t lightpanda-browser:arm64 .
```

### 参考资料

- [Docker BuildKit SSH 文档](https://docs.docker.com/build/building/secrets/#ssh-mounts)
- [Dockerfile 语法参考](https://docs.docker.com/engine/reference/builder/)
- [Docker BuildKit 文档](https://docs.docker.com/build/buildkit/)

