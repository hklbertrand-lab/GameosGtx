// GameOS RE — étape 5 : module kprobe pour tracer les 3 getters de micrologiciel.
// register_kprobe() du cœur noyau n'a pas la restriction « notrace function » de
// l'interface tracefs : il peut donc sonder les fonctions du module NVIDIA.
// On enregistre par NOM DE SYMBOLE : le cadre kprobe désarme la sonde quand le
// module nvidia est déchargé et la RÉ-ARME automatiquement au rechargement, à
// l'état MODULE_STATE_COMING, c.-à-d. AVANT que module_init ne s'exécute. On
// attrape donc l'appel aux getters pendant la toute première init (chargement
// du firmware). Le pre_handler imprime la pile d'appel (dump_stack) dans dmesg.
#include <linux/module.h>
#include <linux/kprobes.h>
#include <linux/kernel.h>
#include <linux/ptrace.h>

static struct kprobe kp[3];
static const char *nm[3]  = { "g615", "g617", "g649" };
static const char *sym[3] = { "_nv048615rm", "_nv048617rm", "_nv048649rm" };

static int gameos_pre(struct kprobe *p, struct pt_regs *regs)
{
	int i;
	const char *tag = "?";
	for (i = 0; i < 3; i++)
		if (p == &kp[i]) { tag = nm[i]; break; }
	pr_info("GAMEOS_KP hit %s %ps\n", tag, (void *)p->addr);
	dump_stack();
	return 0;
}

static int __init gameos_init(void)
{
	int i, n = 0, ret;
	for (i = 0; i < 3; i++) {
		kp[i].symbol_name = sym[i];
		kp[i].pre_handler = gameos_pre;
		ret = register_kprobe(&kp[i]);
		if (ret == 0) {
			pr_info("GAMEOS_KP armed %s (%s)\n", nm[i], sym[i]);
			n++;
		} else {
			pr_info("GAMEOS_KP FAIL %s (%s) ret=%d\n", nm[i], sym[i], ret);
			kp[i].symbol_name = NULL;
		}
	}
	pr_info("GAMEOS_KP ready, %d probe(s)\n", n);
	return 0;
}

static void __exit gameos_exit(void)
{
	int i;
	for (i = 0; i < 3; i++)
		if (kp[i].symbol_name)
			unregister_kprobe(&kp[i]);
	pr_info("GAMEOS_KP unloaded\n");
}

module_init(gameos_init);
module_exit(gameos_exit);
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("GameOS RE firmware-getter kprobe tracer");
