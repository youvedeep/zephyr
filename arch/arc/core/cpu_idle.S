/*
 * Copyright (c) 2014 Wind River Systems, Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/**
 * @file
 * @brief CPU power management
 *
 * CPU power management routines.
 */

#define _ASMLANGUAGE

#include <nano_private.h>
#include <offsets.h>
#include <toolchain.h>
#include <sections.h>
#include <arch/cpu.h>

GTEXT(nano_cpu_idle)
GTEXT(nano_cpu_atomic_idle)
GDATA(nano_cpu_sleep_mode)

#if defined(CONFIG_NANOKERNEL) && defined(CONFIG_TICKLESS_IDLE)
	GTEXT(_power_save_idle)
#endif

SECTION_VAR(BSS, nano_cpu_sleep_mode)
	.word 0

#if defined(CONFIG_NANOKERNEL) && defined(CONFIG_TICKLESS_IDLE)
.macro enter_tickless_idle
	/* interrupts are locked when entering here */
	push_s blink
	jl _power_save_idle
	pop_s blink
.endm
#else
	#define enter_tickless_idle
#endif

/*
 * @brief Put the CPU in low-power mode
 *
 * This function always exits with interrupts unlocked.
 *
 * void nanCpuIdle(void)
 */

SECTION_FUNC(TEXT, nano_cpu_idle)

	enter_tickless_idle

	ld r1, [nano_cpu_sleep_mode]
	or r1, r1, (1 << 4) /* set IRQ-enabled bit */
	sleep r1
	j_s.nd [blink]
	nop

/*
 * @brief Put the CPU in low-power mode, entered with IRQs locked
 *
 * This function exits with interrupts restored to <key>.
 *
 * void nano_cpu_atomic_idle(unsigned int key)
 */
SECTION_FUNC(TEXT, nano_cpu_atomic_idle)

	enter_tickless_idle

	push_s blink
	st.a r0,[sp,-4]
	st.a fp,[sp,-4]
	mov_s fp,sp
	bl _idle_hook
	mov_s r2, r0
	ld.ab fp,[sp,4]
	ld.ab r0,[sp,4]
	pop_s blink
	breq r2, 0, _idle_exit

	ld r1, [nano_cpu_sleep_mode]
	or r1, r1, (1 << 4) /* set IRQ-enabled bit */
	sleep r1

.balign 4
_idle_exit:
	j_s.d [blink]
	seti r0
