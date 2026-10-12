# ReminiPro tweak 骨架

## 这是什么
Remini 本地 UI 门闸的运行时 hook 骨架(第四轮)。配合 HOOK.md 阅读。
**只骗本地 UI/保存门闸, 不解锁云端 AI/积分/额度/S2S**(服务端说了算)。

## 为什么是 offset-hook 而不是纯 %hook
Remini 业务是 **stripped Swift**, 没有 ObjC selector, Logos `%hook` 钩不到。
因此 Bool getter / showPaywallIfNeeded 用 `MSHookFunction` 按「文件 VA - 0x100000000」
的入口偏移挂, 运行时地址 = dyld slide + 偏移。`%hook` 只用于残留 ObjC 类(如收据刷新)。

## 换版本必做: resolve_offsets
`Tweak.x` 顶部 `OFF_*` 必须用**本机同版本 dump** 复核(跨版本写死会崩):

1. 砸壳得到 decrypted `Remini`(cryptid=0)。
2. r2 定位 Bool getter 入口。锚点(本分析环境, 原始 SHA 08bf2dc4…):
   - `isPro` 字段元数据簇: 0x10415c9fc / 0x10415d774 / 0x10415ddc0
   - `isProeminentSaveFlowEnabled`: 0x10415c950
   - `savingLockShowPaywallOnToolTap`: 0x104155f14
   - `freeTierSaveLimit`: 0x104142f8c
   - showPaywall 证据串: 0x1013e80d8; fail 簇 0x101539xxx
   - UserMonetizationStatus 判别/描述 func: 0x10151e460 (**不要 hook**)
   - 这些是 __swift5_fieldmd 记录 / 字符串引用, 需顺藤摸到对应 getter 函数入口。
   示例:
     ```
     r2 -q -c 'e anal.jmp.tbl=true; af @ <getter_entry>; pdf @ <getter_entry>' Remini.decrypted
     ```
   确认是「读某字节/字段, csel 产 0/1, ret」的小 getter 后, 填入 OFF_*。
3. `make package` (越狱) 或走 §TrollStore 静态注入。

## TrollStore(无越狱)静态注入
见 HOOK.md §5B: 把 `.dylib` 放进 .app/Frameworks, 用 insert_dylib 加 LC_LOAD_DYLIB
(@executable_path/Frameworks/ReminiPro.dylib), ldid 重签整包, TrollStore 安装。
MSHookFunction 需自带实现(ellekit 静态库)。

## 安全原则
- 只 hook 返回 Bool/Int/无payload枚举的点 → 永不构造 Set<SubscriptionFeature> → 不崩。
- 绝不 hook/伪造 proUserSubscribed/proUserFree(带关联值) → 否则野指针。
