import XMonad
import XMonad.Hooks.DynamicLog
import XMonad.Util.Run ( spawnPipe )
import XMonad.Util.EZConfig ( additionalKeys )
import System.IO ( hPutStrLn )
import System.Exit ( ExitCode(ExitSuccess), exitWith )
import XMonad.Config.Gnome ( gnomeConfig )
import XMonad.Hooks.ManageHelpers
import XMonad.Config.Desktop ( desktopLayoutModifiers )
import XMonad.Layout.NoBorders ( smartBorders )
import XMonad.Hooks.ManageHelpers ( isFullscreen, isDialog, doFullFloat )
import XMonad.Hooks.UrgencyHook ( NoUrgencyHook(NoUrgencyHook), withUrgencyHook )
import XMonad.Layout.ComboP ( Property(Role) )
import XMonad.Layout.PerWorkspace ( onWorkspace )
import Control.Monad ( liftM2 )
import XMonad.Layout.IM ( withIM )
import XMonad.Layout.Reflect ( reflectHoriz )
import qualified XMonad.StackSet as W ( sink, shift, greedyView )

main = do
    -- I use two dzen bars, the left one contains the Xomand workspaces
    -- and title etc., eth right one contains the output from conky
    -- with some stats etc.
    status <- spawnPipe myDzenStatus
    conky  <- spawnPipe myDzenConky

    -- Since gnome isn't starting any init script like .xinitrc, I'm running
    -- my own init script manually
    init <- spawn "/home/poe/.xmonad/startxmonad"

    -- I'm still running Xomand as a gnome session which is nice to keep
    -- some custom settings, power management etc.
    -- Might swap that later...
    xmonad $ withUrgencyHook NoUrgencyHook $ gnomeConfig {
        -- Mix custom manage hook with the gnome one
        manageHook = myManageHook <+> manageHook gnomeConfig
        -- Defining 9 workspaces, some of them "named"
        , workspaces = ["1:www", "2:mail", "3:chat", "4:music", "5:edit", "6", "7", "8", "9"]
        , layoutHook = myLayout
        , logHook = myLogHook status
        -- Use Windows key for all the keyboard shotcuts instead of Alt
        , modMask = mod4Mask
        -- Gnome terminal sucks, use urxvt instead
        , terminal = "terminator"
        -- I like the focused windo to be the one the mouse is hovering
        -- over. Takes a bit to get used to...
        , focusFollowsMouse = True

    -- Define some additional key bindings
    } `additionalKeys`
        -- Use Ctrl + Alt + L to lock the screen
        [ ((mod1Mask .|. controlMask, xK_l), spawn "gnome-screensaver-command --lock")
        -- Take a delayed screen shot using Ctrl + Print
        , ((controlMask, xK_Print), spawn "sleep 0.2; scrot -s")
        -- Take a screen shot using the Print key
        , ((0, xK_Print), spawn "scrot")
        -- Use Windows + P to open dmenu
        , ((mod4Mask, xK_p), spawn "dmenu_run -b")
        -- As former Windows user I like to have Windows + E for nautilus
        , ((mod4Mask, xK_e), spawn "nautilus")
        -- Use Windows + Shift + Q to exit XMonad (logout)
        , ((mod4Mask .|. shiftMask, xK_q), io (exitWith ExitSuccess))
	]

-- The Manage hook places windows on certain workspaces automatically
-- and takes care of fullscreen / floating windows
myManageHook = composeAll . concat $
    [ [isDialog --> doFloat]
    , [isFullscreen --> doFullFloat]
    , [className =? c --> doFloat | c <- myCFloats]
    , [title =? t --> doFloat | t <- myTFloats]
    , [resource =? r --> doFloat | r <- myRFloats]
    , [(className =? i <||> resource =? i) --> doIgnore | i <- myIgnores]
    , [(className =? x <||> title =? x <||> resource =? x) --> doSink | x <- mySinks]
    , [(className =? x <||> title =? x <||> resource =? x) --> doFullFloat | x <- myFullscreens]
    , [(className =? x <||> title =? x <||> resource =? x) --> doShift "1:www" | x <- my1Shifts]
    , [(className =? x <||> title =? x <||> resource =? x) --> doShift "2:mail" | x <- my2Shifts]
    , [(className =? x <||> title =? x <||> resource =? x) --> doShift "3:chat" | x <- my3Shifts]
    , [(className =? x <||> title =? x <||> resource =? x) --> doShift "4:music" | x <- my4Shifts]
    , [(className =? x <||> title =? x <||> resource =? x) --> doShiftAndGo "5:edit" | x <- my5Shifts]
    , [(className =? x <||> title =? x <||> resource =? x) --> doShiftAndGo "6" | x <- my6Shifts]
    , [(className =? x <||> title =? x <||> resource =? x) --> doShiftAndGo "7" | x <- my7Shifts]
    , [(className =? x <||> title =? x <||> resource =? x) --> doShiftAndGo "8" | x <- my8Shifts]
    , [(className =? x <||> title =? x <||> resource =? x) --> doShiftAndGo "9" | x <- my9Shifts]
    ]
    where
    -- Hook used to shift windows without focusing them
    doShiftAndGo = doF . liftM2 (.) W.greedyView W.shift
    -- Hook used to push floating windows back into the layout
    -- This is used for gimp windwos to force them into a layout.
    doSink = ask >>= \w -> liftX (reveal w) >> doF (W.sink w)
    -- Float dialogs, Download windows and Save dialogs
    myCFloats = ["Sysinfo", "XMessage"]
    myTFloats = ["Downloads", "Save As..."]

    myRFloats = ["Dialog"]
    -- Ignore gnome leftovers
    myIgnores = ["Unity-2d-panel", "Unity-2d-launcher", "desktop_window", "kdesktop"]
    mySinks = ["gimp"]
    -- Run VLC, firefox and VLC on fullscreen
    myFullscreens = ["vlc", "Image Viewer", "firefox"]
    -- Define default workspaces for some programs
    my1Shifts = ["Firefox-bin", "Firefox", "firefox", "Firefox Web Browser", "opera", "Opera"]
    my2Shifts = ["thunderbird", "Thunderbird-bin", "thunderbird-bin", "Thunderbird"]
    my3Shifts = ["Pidgin Internet Messenger", "Buddy List", "pidgin", "skype", "skype-wrapper", "Skype"]
    my4Shifts = ["Banshee"]
    my5Shifts = ["geany", "eclipse", "Eclipse"]
    my6Shifts = ["hotot"]
    my7Shifts = ["urxvt"]
    my8Shifts = ["gimp", "GIMP Image Editor"]
    my9Shifts = ["vlc", "nautilus"]

-- Define a special layout for the GIMP workspace with the two toolbar
-- windows on each side of the main windows.
-- Also change the ratio for main/other windows to the golden section
-- instead of 1:1
myLayout = onWorkspace "8" gimpLayout $ smartBorders (desktopLayoutModifiers (resizableTile ||| Mirror resizableTile ||| Full))
    where
    resizableTile = Tall nmaster delta ratio
    gimpLayout = (withIM (0.12) (Role "gimp-toolbox") $ reflectHoriz $ withIM (0.15) (Role "gimp-dock") Full)
    nmaster = 1
    ratio = toRational (2/(1+sqrt(5)::Double))
    delta = 3/100

-- Forward the window information to the left dzen bar and format it
myLogHook h = dynamicLogWithPP $ myDzenPP { ppOutput = hPutStrLn h }

-- Left bar is 1000px wide, right one 500, rest is taken by trayer
-- myDzenStatus = "dzen2 -x '0' -w '1000' -ta 'l'" ++ myDzenStyle
-- myDzenConky  = "conky -c ~/.xmonad/conkyrc | dzen2 -x '1000' -w '500' -ta 'r'" ++ myDzenStyle
myDzenStatus = "dzen2 -w '500' -ta 'l'" ++ myDzenStyle
myDzenConky  = "conky -c ~/.xmonad/conkyrc | dzen2 -x '500' -w '704' -ta 'r'" ++ myDzenStyle
myDzenStyle  = " -h '20' -fg '#777777' -bg '#222222' -fn 'arial:bold:size=11'"

-- Very plain formatting, non-empty workspaces are highlighted,
-- urgent workspaces (e.g. active IM window) are highlighted in red
myDzenPP  = dzenPP
    { ppCurrent = dzenColor "#3399ff" "" . wrap " " " "
    , ppHidden  = dzenColor "#dddddd" "" . wrap " " " "
    , ppHiddenNoWindows = dzenColor "#777777" "" . wrap " " " "
    , ppUrgent  = dzenColor "#ff0000" "" . wrap " " " "
    , ppSep     = "  "
    , ppLayout  = \y -> ""
    , ppTitle   = dzenColor "#ffffff" "" . wrap " " " "
    }
