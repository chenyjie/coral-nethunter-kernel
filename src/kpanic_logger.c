// SPDX-License-Identifier: GPL-2.0
/*
 * kpanic_logger - dump the kernel log into a reserved RAM region as plain
 * text on panic/oops, plus boot-stage traces.
 *
 * The same region is exposed to userspace by the stock access_ramoops driver
 * (/dev/access-ramoops), so the dump can be read back as root after the next
 * boot, with no dependency on pstore or its encryption.
 */
#define pr_fmt(fmt) "kpanic: " fmt

#include <linux/init.h>
#include <linux/io.h>
#include <linux/jiffies.h>
#include <linux/kernel.h>
#include <linux/kmsg_dump.h>
#include <linux/module.h>
#include <linux/printk.h>
#include <linux/string.h>
#include <linux/types.h>

/* coral: alt_ramoops_region, userspace node /dev/access-ramoops */
#define KPANIC_PHYS		0xA49FF000UL
#define KPANIC_SIZE		0x200000UL

#define KPANIC_MAGIC		"KPANIC01"
#define KPANIC_META_OFF		0x00000UL
#define KPANIC_TRACE_OFF	0x00040UL
#define KPANIC_TRACE_MAX	256
#define KPANIC_LOG_OFF		0x10000UL
#define KPANIC_LOG_MAX		(512 * 1024)

enum kpanic_kind {
	KPANIC_STAGE = 1,
	KPANIC_SNAP = 2,
	KPANIC_PANIC = 3,
	KPANIC_OOPS = 4,
};

struct kpanic_meta {
	char magic[8];
	u32 version;
	u32 trace_count;
	u64 boot_jiffies;
};

struct kpanic_trace {
	u32 stage;
	u32 seq;
	u64 jiffies;
};

struct kpanic_hdr {
	char magic[8];
	u32 version;
	u32 seq;
	u32 kind;
	u32 stage;
	u64 jiffies;
	u32 len;
	u32 rsvd;
} __packed;

static void __iomem *kpanic_va;
static u32 kpanic_seq;
static u32 kpanic_stage;
static u32 kpanic_trace_count;

static void kpanic_emit(u32 kind, const char *buf, size_t len)
{
	struct kpanic_hdr h;

	if (!kpanic_va)
		return;
	if (len > KPANIC_LOG_MAX)
		len = KPANIC_LOG_MAX;

	memset(&h, 0, sizeof(h));
	memcpy(h.magic, KPANIC_MAGIC, sizeof(h.magic));
	h.version = 1;
	h.seq = ++kpanic_seq;
	h.kind = kind;
	h.stage = kpanic_stage;
	h.jiffies = get_jiffies_64();
	h.len = (u32)len;

	memcpy_toio(kpanic_va + KPANIC_LOG_OFF, &h, sizeof(h));
	if (len && buf)
		memcpy_toio(kpanic_va + KPANIC_LOG_OFF + sizeof(h), buf, len);
}

static void kpanic_trace_add(u32 stage)
{
	struct kpanic_trace t;

	if (!kpanic_va || kpanic_trace_count >= KPANIC_TRACE_MAX)
		return;

	t.stage = stage;
	t.seq = ++kpanic_seq;
	t.jiffies = get_jiffies_64();
	memcpy_toio(kpanic_va + KPANIC_TRACE_OFF +
		    kpanic_trace_count * sizeof(t), &t, sizeof(t));
	kpanic_trace_count++;
	memcpy_toio(kpanic_va + offsetof(struct kpanic_meta, trace_count),
		    &kpanic_trace_count, sizeof(kpanic_trace_count));
}

static void kpanic_dump(struct kmsg_dumper *dumper,
			enum kmsg_dump_reason reason)
{
	static char buf[KPANIC_LOG_MAX];
	size_t len = 0;
	u32 kind;

	kind = (reason == KMSG_DUMP_PANIC) ? KPANIC_PANIC :
	       (reason == KMSG_DUMP_OOPS ? KPANIC_OOPS : KPANIC_SNAP);

	if (!kmsg_dump_get_buffer(dumper, true, buf, sizeof(buf), &len))
		len = 0;

	kpanic_emit(kind, buf, len);
}

static struct kmsg_dumper kpanic_dumper = {
	.dump = kpanic_dump,
	.max_reason = KMSG_DUMP_OOPS,
};

/* record a stage and take a fresh snapshot of the log tail */
static void kpanic_mark(u32 stage)
{
	kpanic_stage = stage;
	kpanic_trace_add(stage);
	kmsg_dump(KMSG_DUMP_OOPS);
}

#define KPANIC_STAGE_FN(name, lvl, num)	\
	static int __init kpanic_stage_##name(void)	\
	{						\
		kpanic_mark(num);			\
		return 0;				\
	}						\
	lvl##_initcall(kpanic_stage_##name)

KPANIC_STAGE_FN(postcore, postcore, 2);
KPANIC_STAGE_FN(arch, arch, 3);
KPANIC_STAGE_FN(subsys, subsys, 4);
KPANIC_STAGE_FN(device, device, 5);
KPANIC_STAGE_FN(late, late, 6);

static int __init kpanic_logger_init(void)
{
	struct kpanic_meta m;

	kpanic_va = ioremap(KPANIC_PHYS, KPANIC_SIZE);
	if (!kpanic_va) {
		pr_err("ioremap %#lx failed\n", (unsigned long)KPANIC_PHYS);
		return 0;
	}

	memset(&m, 0, sizeof(m));
	memcpy(m.magic, KPANIC_MAGIC, sizeof(m.magic));
	m.version = 1;
	m.trace_count = 0;
	m.boot_jiffies = get_jiffies_64();
	memcpy_toio(kpanic_va + KPANIC_META_OFF, &m, sizeof(m));

	kmsg_dump_register(&kpanic_dumper);
	pr_info("armed at %#lx, log off %#x\n", (unsigned long)KPANIC_PHYS,
		KPANIC_LOG_OFF);
	kpanic_mark(1);
	return 0;
}
early_initcall(kpanic_logger_init);
