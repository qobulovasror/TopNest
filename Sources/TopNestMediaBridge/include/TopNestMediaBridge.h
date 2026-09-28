#pragma once

// /usr/bin/perl ichida DynaLoader orqali chaqiriladi (perl XSUB imzosi: ikki argument e'tiborsiz).
// macOS 15.4+ da MediaRemote faqat Apple imzoli jarayonlarga to'liq ma'lumot beradi.
void tn_stream(void *interpreter, void *cv);
void tn_command(void *interpreter, void *cv);
