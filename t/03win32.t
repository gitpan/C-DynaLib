# Win32/cygwin/mingw tests only
use Test;
BEGIN {
    if ($^O !~ /(cygwin|MSWin|mingw)/) {
	print"1..0 # skip This module does only work on Windows\n";
	exit 0;
    } else {
      plan tests => 3
    }
};

use C::DynaLib;
use sigtrap;

=pod

This file tests the C::DynaLib package on Windows
To run it after installation, type `perl <thisfile>'.
If successful, it will create a window with a message in the
center.

The program is modeled after the kind of "hello world" examples found
in introductory books on Windows programming in C.  However, Perl
lacks an important feature of C, namely the preprocessor (unless
someone has written a Cpp module that I don't know about?)  Therefore,
all function declarations and constants from <windows.h> are
hard-coded.

Another difficulty is the use of resources.  Windows resources are
binary data associated with an application; for example, menus,
bitmaps, and dialog box templates.  Typically, resources are linked
into the program's .exe file.  Of course, Perl programs are text and
don't use the binary format which can contain resources.  Although it
is possible to construct at run time the objects which would otherwise
be stored as resources, this is rather wasteful and complicated.

One alternative is to put the resources in a DLL or EXE which the Perl
program would then load via LoadLibrary().  A more radical solution
would be to generate a cross-breed file which has the EXE format and
is at the same time parsable by perl.  A similar principle is used by
the pl2bat utility in the Win32 Perl distribution.  However, the
"Portable Executable" format used by Win32 is quite a bit nastier on
text editors than are .bat files.  Wordpad, for instance, won't open
them at all, and Notepad leaves them hopelessly corrupt when you save.

Be that as it may, John has developed a pl2exe.pl program that does what
its name suggests.  It takes a perl script and adds some stuff at the
beginning to make it have the PE format (well, close enough to fool
Windows).  When executed, the program invokes perl on itself the way a
pl2bat script does (and avoids the 9-argument limit on Windows 95,
btw).  The thing lacking in pl2exe that would make it really useful is
a way to link in resources without disrupting the delicate PE/script
balance.

One final note about this file.  This is a demo/test program.  It is
not necessarily good coding style.

=cut

use 5.00402;

use C::DynaLib;
use C::DynaLib::Struct;
use strict;

my $user32 = new C::DynaLib("USER32");
ok ($user32);
my $gdi32 = new C::DynaLib("GDI32");
ok ($gdi32);

#typedef struct _WNDCLASS {    // wc
#
#    UINT    style;
#    WNDPROC lpfnWndProc;
#    int     cbClsExtra;
#    int     cbWndExtra;
#    HANDLE  hInstance;
#    HICON   hIcon;
#    HCURSOR hCursor;
#    HBRUSH  hbrBackground;
#    LPCTSTR lpszMenuName;
#    LPCTSTR lpszClassName;
#} WNDCLASS;
Define C::DynaLib::Struct('WNDCLASS',
	I => ['style'],
        I => ['lpfnWndProc'],
        i => ['cbClsExtra'],
        i => ['cbWndExtra'],
        I => ['hInstance'],
        I => ['hIcon'],
        I => ['hCursor'],
        I => ['hbrBackground'],
        p => ['lpszMenuName'],
        p => ['lpszClassName'],
);

# The results of much sifting through C header files:

my $PostQuitMessage = $user32->DeclareSub("PostQuitMessage",
	"i",  # return type
        "i");  # argument type(s)
my $GetClientRect = $user32->DeclareSub("GetClientRect",
	"i",
        "i", "P");
my $BeginPaint = $user32->DeclareSub("BeginPaint",
	"i",
        "i", "P");
my $DrawText = $user32->DeclareSub("DrawTextA",
	"i",
        "I", "p", "I", "P", "I");
my $EndPaint = $user32->DeclareSub("EndPaint",
	"i",
        "i", "P");
my $DefWindowProc = $user32->DeclareSub("DefWindowProcA",
	"i",
        "i", "i", "i", "i");
my $LoadIcon = $user32->DeclareSub("LoadIconA",
	"i",
        "i", "i");
my $LoadCursor = $user32->DeclareSub("LoadCursorA",
	"i",
        "i", "i");
my $GetStockObject = $gdi32->DeclareSub("GetStockObject",
	"i",
        "i");
my $RegisterClass = $user32->DeclareSub("RegisterClassA",
	"i",
        "P");
my $CreateWindowEx = $user32->DeclareSub("CreateWindowExA",
	"i",
        "i", "p", "p", "i", "i", "i", "i", "i", "i", "i", "i", "i");
my $ShowWindow = $user32->DeclareSub("ShowWindow",
	"i",
        "i", "i");
my $UpdateWindow = $user32->DeclareSub("UpdateWindow",
	"i",
        "i");
my $GetMessage = $user32->DeclareSub("GetMessageA",
	"i",
        "P", "i", "i", "i");
my $TranslateMessage = $user32->DeclareSub("TranslateMessage",
	"i",
        "P");
my $DispatchMessage = $user32->DeclareSub("DispatchMessageA",
	"i",
        "P");

#
# Main window's callback.
#
sub window_proc {
	my ($hwnd, $uMsg, $wParam, $lParam) = @_;

        # Wanna log your window messages?
	#print "hwnd=$hwnd, uMsg=$uMsg, wParam=$wParam, lParam=$lParam\n";

	if ($uMsg == 0x0201	# WM_LBUTTONDOWN
		|| $uMsg == 0x0002	# WM_DESTROY
	) {
		&$PostQuitMessage(0);
		return 0;
	} elsif ($uMsg == 0x000F) {	# WM_PAINT
		my $text = "Hello from Perl!";
                # This should be big enough for a PAINTSTRUCT, I hope:
		my $ps = "\0" x 1024;
		my $rect = "\0" x 64;
		my $hdc;
		&$GetClientRect($hwnd, $rect);
		$hdc = &$BeginPaint($hwnd, $ps);
		&$DrawText($hdc, $text, length($text), $rect,
			0x00000025);	# DT_SINGLELINE | DT_CENTER | DT_VCENTER
		&$EndPaint($hwnd, $ps);
		return 0;
	}
	return &$DefWindowProc($hwnd, $uMsg, $wParam, $lParam);
}

my $wnd_proc = new C::DynaLib::Callback(
	\&window_proc, "i", "i", "i", "i", "i");

#
# Register the window class.
#
my $wc;
my $rwc = tie $wc, 'WNDCLASS';
$rwc->style(0x0003);	# CS_HREDRAW | CS_VREDRAW
$rwc->lpfnWndProc($wnd_proc->Ptr());
$rwc->hInstance(0x00400000);
$rwc->hIcon(&$LoadIcon(0, 32512));
$rwc->hCursor(&$LoadCursor(0, 32512));
$rwc->hbrBackground(&$GetStockObject(0));  # WHITE_BRUSH
$rwc->lpszClassName("w32test");
&$RegisterClass($wc) or die "can't register window class";

#
# Create the window.
#
my $title_text = "Perl Does Win32";
my $hwnd = &$CreateWindowEx(0, $rwc->lpszClassName,
	$title_text,
	0x00CF0000,	# WS_OVERLAPPEDWINDOW
	0x80000000,     # CW_USEDEFAULT
	0x80000000, 0x80000000, 0x80000000,
	0, 0, $rwc->hInstance,
	0) or die "can't create window";

ok($hwnd);

&$ShowWindow($hwnd, 10);	# SW_SHOWDEFAULT
&$UpdateWindow($hwnd);

#
# Message loop.
#
my $msg = "\0" x 64;
while (&$GetMessage($msg, 0, 0, 0)) {
	&$TranslateMessage($msg);
	&$DispatchMessage($msg);
}
