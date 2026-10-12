// ReminiPro.x  —  Remini 运行时 Hook 骨架（第四轮）
// 目标: com.bendingspoons.remini  (arm64 Mach-O PIE, base 0x100000000)
// 策略: 只 hook「返回 Bool/Int/无payload枚举」的下游判定, 绝不伪造带关联值的
//       UserMonetizationStatus 枚举(会野指针崩)。
// 注入: 越狱(ellekit/Substrate) 直接用; TrollStore 需静态注入 dylib(见 HOOK.md §5B)。
//
// ⚠️ stripped Swift: 下面 OFF_* 是「文件 VA - 0x100000000」的函数入口偏移锚点,
//    必须用本机同版本 dump 复核(见 README resolve_offsets)。写死跨版本会崩。

#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <substrate.h>

// ====== 需按本机 dump 核对的偏移 (base 0x100000000) ======
// 这些是「返回 Bool」的属性 getter 入口。锚点来自 __swift5_fieldmd + 调用点簇,
// 真实 getter 入口随版本浮动, 以 r2 复核为准(README)。
#define OFF_isProUser_getter              0x0   // TODO: WatermarksManagerState.isProUser getter 入口
#define OFF_savingLockShowPaywall_getter  0x0   // TODO: savingLockShowPaywallOnToolTap getter
#define OFF_isProeminentSaveFlow_getter   0x0   // TODO: isProeminentSaveFlowEnabled getter
#define OFF_freeTierSaveLimit_getter      0x0   // TODO: freeTierSaveLimit getter (返回 Int)
#define OFF_settings_isPro_getter         0x0   // TODO: 设置页 VM isPro getter
#define OFF_showPaywallIfNeeded_impl      0x0   // TODO: showPaywallIfNeeded 实现入口

// 已确认的真实锚点(供定位, 非直接 hook 入口):
//   枚举判别/描述 func.0x10151e460 (cmp tag #0..#4) —— 不要 hook
//   Crisper 解码 ldrb w25,[x0,0x20] @0x100c00404 (已被字节补丁 P10 处理)
//   proUserSubscribed 串簇 0x100c00dd8/e88/f30; 0x10151eb0c
//   showPaywall 证据串 0x1013e80d8; failShowPaywall 簇 0x101539xxx

static uintptr_t g_base = 0;
static uintptr_t slide(void){ return (uintptr_t)_dyld_get_image_vmaddr_slide(0); }
static void* rt(uint64_t fileVA){ // fileVA(0x1.........) -> 运行时地址
    if(!fileVA) return NULL;
    return (void*)(g_base + (fileVA - 0x100000000ULL));
}

// ---------- H1/H2/H5: Bool getter -> 恒 true ----------
static bool (*o_isProUser)(void*);
static bool n_isProUser(void* self){ return true; }

static bool (*o_settingsIsPro)(void*);
static bool n_settingsIsPro(void* self){ return true; }

// savingLockShowPaywallOnToolTap: 这是「锁」, 要返回 false(不锁)
static bool (*o_savingLock)(void*);
static bool n_savingLock(void* self){ return false; }

// isProeminentSaveFlowEnabled: 允许直接保存流 -> true
static bool (*o_proeminentSave)(void*);
static bool n_proeminentSave(void* self){ return true; }

// ---------- H3: freeTierSaveLimit -> 巨大值(等效无限额) ----------
static long (*o_freeSaveLimit)(void*);
static long n_freeSaveLimit(void* self){ return 0x7fffffff; }

// ---------- H4: showPaywallIfNeeded -> notDisplayed(无payload, 安全) ----------
// 返回值是 PaywallPresentationResult 枚举。notDisplayed 是无关联值 case。
// 该枚举 tag 需本机核对(通常单字节判别子, notDisplayed 的 tag=? 以 dump 为准)。
// 这里给出「吞掉调用并返回无payload枚举 tag」的模板。
#define TAG_notDisplayed 0   // TODO: 以 dump 核对 notDisplayed 的 tag
static long (*o_showPaywall)(void*);
static long n_showPaywall(void* self){ return TAG_notDisplayed; }

// ---------- (可选) H6: 收据刷新失败回调, ObjC %hook ----------
// 字节补丁 P7–P9 已盖, 这里保留示例: 若仍弹 AppleID, 可吞错误。
%hook StoreReceiptRefresher   // Chocolate.StoreReceiptRefresher (残留 ObjC 类名可能需带模块前缀)
- (void)request:(id)req didFailWithError:(id)err {
    // 直接当作完成, 不冒泡出登录 UI
    return;
}
%end

%ctor {
    @autoreleasepool {
        g_base = (uintptr_t)_dyld_get_image_header(0); // 主可执行文件基址
        // NSLog(@"[ReminiPro] base=%p slide=%p", (void*)g_base, (void*)slide());

        if (OFF_isProUser_getter)
            MSHookFunction(rt(0x100000000+OFF_isProUser_getter), (void*)n_isProUser, (void**)&o_isProUser);
        if (OFF_settings_isPro_getter)
            MSHookFunction(rt(0x100000000+OFF_settings_isPro_getter), (void*)n_settingsIsPro, (void**)&o_settingsIsPro);
        if (OFF_savingLockShowPaywall_getter)
            MSHookFunction(rt(0x100000000+OFF_savingLockShowPaywall_getter), (void*)n_savingLock, (void**)&o_savingLock);
        if (OFF_isProeminentSaveFlow_getter)
            MSHookFunction(rt(0x100000000+OFF_isProeminentSaveFlow_getter), (void*)n_proeminentSave, (void**)&o_proeminentSave);
        if (OFF_freeTierSaveLimit_getter)
            MSHookFunction(rt(0x100000000+OFF_freeTierSaveLimit_getter), (void*)n_freeSaveLimit, (void**)&o_freeSaveLimit);
        if (OFF_showPaywallIfNeeded_impl)
            MSHookFunction(rt(0x100000000+OFF_showPaywallIfNeeded_impl), (void*)n_showPaywall, (void**)&o_showPaywall);
    }
}
