# lyricsHelper
## (English) Introduction:
A Musescore(3.5) plugin intends to help input lyrics. 
It is designed for East Asian languages (monosyllabic languages like Chinese, Cantonese, Japanese and Korean etc.) 
but also potentially work for other language texts with some workarounds.

### Installation:
1. Download then put the entire repository (lyricsHelper-main\) under `%USER%\Documents\MuseScore 3\Plugins\`
2. Go to MuseScore menu toolbar -> `plugins` -> `plugin manager`
3. Tick the checkbox of "Lyrics Helper," define a preferred shortcut if you like.
4. Click MuseScore menu toolbar -> `plugins` -> `Lyrics Helper`, and enjoy!

### Functionality:
You need to select a txt file by clicking "..." first to enable all the buttons. Or just drag-drop a text over the plugin!

Use mouse to `right click` "..." to open settings pop-up. 

1. "◀" and "▶" button moves the lyrics navigator (the highlighting on character) backward/foward by 1 step. Or just click on the lyrics to select the wanted character!

2. "Syllable" button adds the character that is highlighted to the selected note. If the "Replace Mode" is on in the Settings, it will overwrites everything if the notes already had lyrics, and will also cut the existed melisma line. 
After adding the lyrics, Then the plugin will automatically select the next available note. (skip rests & tied notes)

Notice: that Syllable, Melisma and Synalepha Buttons will only work when **A SINGLE NOTE** is selected.

4. "Melisma" button extends the melisma line from the previous lyrics character to the selected note. 

Notice:The melisma line must be musically meaningful, for example, if you selected a note in the middle of the tied notes but there is lyrics on the first note of the tie, the plugin will do nothing since it is meaningless to extend the melisma line to the middle of the tie. Also the melisma will not cross a rest because it is also meaningless in this case. 
After extending the melisma line, the plugin will find the next available note and select it. (skip rests & tied notes)

4. "Synalepha" button immediately concatenates the highlighted character to the lyrics if the selected note **HAS** lyrics. If not, the plugin will find the previous available note to concatenate the character.
This design is for the sake of the continuity of workflow. The logic of finding the previous note is the reversed way of "Syllable" button finds the next available note. So the user can easily add synalepha in the middle of the lyrics editing, and not interrupted by the neccessity of using mouse to click the the previous note.

5. In the previous versions, users are able to simply undo plugin's action by hitting Ctrl+Z, however, this undo action won't revert the lyrics navigator's (that highlighted character) movements back in the lyrics box. In this version, the plugin has an emulated "undo stack" to identity whether the undone actions' source were from the lyricsHelper. Thus, the undo in the MuseScore can also revert back the lyrics nagivator's position. However, due to the limited API exposure of MuseScore, this feature is unstable and might break in some corner cases. Let's hope MuseScore 4.0 can give developers more API accessibilities!

## (Simplified Chinese) 简介:
此歌词插件适配MuseScore 3.5及以上的版本，这个插件是在MuseScore 3.6.2环境下开发的，我推荐您在使用本插件之前更新您的MuseScore至最新版本。
此插件适合单音节语言(Monosyllabic Language)歌词的编辑，例如东亚语言：中文、粤语、日语、韩语。
不推荐使用此插件编辑多音节语言例如印欧语系语言（比如英语）的歌词，但是您仍然可以使用“多音”(Synalepha)按钮来塞进多个音节。

### 安装步骤：
1. 下载此repository（lyricsHelper-main）内的所有文件，并放在 `"%USER%\Documents\MuseScore 3\插件"` 目录下。
2. 打开MuseScore，在菜单栏里点击 `插件` -> `插件管理器`。
3. 在插件管理器内将Lyrics Helper勾选，点击确定。
4. 本插件就应该会出现在菜单栏“`插件`”下，点击就可以使用了！

### 功能说明
您必须先点击“...”来加载一个歌词，或者直接把歌词文件拖拽到插件上也可以。

用鼠标右键点击“...”可以打开设置窗口。

1. "◀" 和 "▶" 键可以移动当前在下方歌词里选择的字，加粗的字即是下一个将被输入的歌词。新版本支持直接在歌词上点击选字了！

注意：下面的“单音”、“转音”和“多音”按钮都需要在乐谱上选中*单个音符*的前提下才能运作。
 
2. “单音” 按钮会将下方歌词里加粗的那个字添加到选中的音符下。如果在设置里面“替换模式”是开启的话，插件会覆盖选中音符下已存在的歌词，如果有转音线的存在，则会切断转音线后将歌词添加至音符下。
歌词添加后，插件会自动选取下一个可用的音符（跳过连音线和休止符）。

4. “转音” 按钮会将上一个歌词的字的转音线延申至当前选中的音符。

转音线会自动按照乐谱规范来生成，违反规范的情况下则不会生成转音线。例如：如果用户选择了一串连音中的一个音符，并且连音的第一个音符下有歌词，那么在此处画转音线则不符合乐谱规范，插件则不会生成转音线。转音线也不能跨越休止符，因为这样的转音线是错误的记谱。
在成功绘制转音线后，插件会自动选取下一个可用的音符（跳过连音线和休止符）。

4. “多音” 按钮的行为较为复杂。如果当前用户选择的音符已经有歌词，那么插件会将加粗的字塞进当前音符的歌词里。
但是如果当前音符的歌词为空，插件则会向前搜寻一个可用的音符，此处搜寻的逻辑和“单音”、“转音”生成后去寻找下一个可用的音符是一样的。这样设计是为了不打断用户的流畅体验，在用户使用“单音”和“转音”按钮后，不必用鼠标重新点击上一个音符也可以方便地向上一个操作的音符塞入歌词。

5. 在以前的版本中，MuseScore自带的“撤销”动作也能撤销插件添加的歌词，但是在插件的歌词栏里高亮的字则不会被撤销回之前的位置。在新版本里，插件用一个模拟的栈来记录哪些动作是插件发出的、哪些不是。所以“撤销”动作现在也可以撤销歌词栏里高亮字的位置，提升用户使用的流畅度。但由于MuseScore自身的限制，我并没有权限访问MuseScore自身的undo/redo stack，所以这个模拟的“撤销”行为在某些复杂的操作下可能会失效。让我们期待MuseScore 4.0能给开发者开放更多的权限。
