# ProtoForge for LazyCat (protoforge-lzcapp)

[ProtoForge](https://github.com/suoten/ProtoForge) 打包为懒猫微服 LPK v2 应用：工业协议仿真平台，一台微服虚拟出整套工业现场设备，MIT 协议，suten 出品。

## 包信息

- 包名：`community.lazycat.app.protoforge`（1.2.5）
- 上游镜像：`docker.io/suoten/protoforge:1.2.5`
- 交付方式：**mirror**（`docker.1ms.run` 加速器，digest 校验），仅发布**喵喵私有商店**
- 目标架构：amd64；`min_os_version: 1.6.0`（`run_as` 需要 lzcos v1.6.0+）

## 转换要点

| docker-compose.simple.yml | LPK |
|---|---|
| `ports: 8000:8000`（Web / REST API） | `upstreams: / → http://protoforge:8000/` |
| 17 个协议端口（原文件里全是注释） | `application.ingress` 逐条声明，容器端口即入站端口 |
| `volumes: protoforge-data:/app/data` | `binds: /lzcapp/var/data:/app/data`（SQLite、`.jwt_secret`、录制数据） |
| `command: sh -c "alembic upgrade head && python -m protoforge.cli demo"` | `command: sh /lzcapp/pkg/content/start.sh`（manifest 的 `command` 只能是字符串，无法表达 `&&`，逻辑移入 content 脚本） |
| `PROTOFORGE_ADMIN_PASSWORD` | 安装向导参数 `login_password` + `simple-inject-password` 自动填充 |
| `PROTOFORGE_JWT_SECRET`（默认硬编码弱密钥） | `{{ stable_secret "protoforge_jwt_secret" }}` |
| `healthcheck: curl -f http://localhost:8000/health` | 原样保留，补 `start_period: 60s`（首启要跑迁移 + demo 播种） |
| 容器以 UID 1000 运行 | `run_as: "1000:1000"`，让 `/lzcapp/var` 按同一身份暴露 owner |

### 与原始 compose 的差异

- **`run` 改成 `demo`**：compose 用的就是 demo。demo 模式会自动创建示例设备/场景，并**启动全部协议服务**——否则协议端口不会监听，ingress 也就没有意义。
- **`logging` / `restart` 不迁移**：由微服系统统一管理。
- **未接入文件选择器拦截**：按需求跳过。

## 协议端口

`lzc-manifest.yml` 里已声明以下 ingress（容器端口 = 入站端口）：

| 协议 | 端口 | 协议 | 端口 |
|---|---|---|---|
| Modbus TCP | 5020/tcp | Rockwell AB | 44818/tcp |
| OPC-UA | 4840/tcp | OPC-DA | 51340/tcp |
| MQTT | 1883/tcp | FANUC FOCAS | 8193/tcp |
| GB28181 SIP | 5060/tcp + udp | MTConnect | 7878/tcp |
| GB28181 RTP | 6000-6999/udp | Mettler-Toledo | 1701/tcp |
| BACnet | 47808/udp | PROFINET | 34964/tcp |
| Siemens S7 | 102/tcp | EtherCAT | 34980/tcp |
| HTTP REST | 8080/tcp | Omron FINS | 9600/udp |
| Mitsubishi MC | 5000/tcp | | |

1.2.5 镜像里还有 IEC 104（2404）、IEC 61850（102，与 S7 同端口）、CoAP（5683）、DDS（7400）四个协议，上游 compose 未列出，本包也**未暴露**；需要时在 `application.ingress` 里按同样格式追加即可。

> ingress 列表是静态的。用户在界面里改协议端口后，外部访问仍需在 manifest 中补上对应端口。

## 部署参数

| 参数 | 类型 | 默认 | 说明 |
|---|---|---|---|
| `login_user` | string | `admin` | 控制台管理员用户名 |
| `login_password` | secret | `$random(len=20)` | 管理员密码，至少 8 位（上游 `min_password_length=8`） |

免密登录用 `builtin://simple-inject-password`，`when: /`。ProtoForge 没有独立登录路由——未登录时 `App.vue` 在根路径渲染 `Login.vue`，路由守卫把未登录用户统一重定向到 `/`。表单是 naive-ui 的 `n-input`，没有 `name`/`id`，所以用类型选择器定位：

```yaml
userSelector: "input.n-input__input-el:not([type='password'])"
passwordSelector: "input.n-input__input-el[type='password']"
```

**demo 模式会重置密码**：`protoforge demo` 默认设置 `PROTOFORGE_RESET_ADMIN_PASSWORD=1`，每次启动都把 admin 密码重置为安装参数的值。好处是免密登录始终有效；代价是在界面里改过的密码重启后不生效。要改这个行为，在 service 的 `environment` 里加 `PROTOFORGE_RESET_ADMIN_PASSWORD=0`。

## 本地构建与验证

```sh
lzc-cli project release
lzc-cli lpk info dist/*.lpk
```

## 自动发布（仅喵喵商店）

`.github/workflows/lazycat.yml` 每日 05:23 UTC（或手动触发）：

1. 检查 `docker.io/suoten/protoforge` 新的 `X.Y.Z` tag（`tag_regex: ^\d+\.\d+\.\d+$`，semver 排序）
2. 校验 `docker.1ms.run` 镜像 digest 与源一致（`require_digest_match: true`），更新 manifest 与版本
3. 构建 LPK → 提交 → 打 tag → GitHub Release（`community.lazycat.app.protoforge-v<version>.lpk`）
4. 发布到喵喵私有商店

所需 Secrets：`APPSTORE_URL`、`APPSTORE_TOKEN`（必填），`APP_ID`、`PRIVATE_STORE_GROUP_CODES`（可选）。组织级已配置。

### 上游标签现状

上游只在推 git tag `v*` 时才产出数字版本镜像标签，目前 git tag 停在 `v1.2.5`（代码已到 1.3.0）。Docker Hub 上可用的数字版本标签只有 `1.2.0` / `1.2.4` / `1.2.5`，另有 `latest` / `master` / `sha-*` 可变标签。因此：

- 本包按需求使用**最新的数字版本标签** `1.2.5`，并让 Action 持续跟踪后续 `X.Y.Z` 标签。
- 上游 `docker-compose.simple.yml` 里写的 `suoten/protoforge:1.2.7` 在 Docker Hub 上并不存在（该 tag 从未发布），属于上游笔误。
- 想拿到 1.3.0 之后的代码，只能改用 `latest` 可变标签 + digest 对比 + `bump: patch`，本包未采用。
