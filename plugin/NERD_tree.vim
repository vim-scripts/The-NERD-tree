" vim global plugin that provides a nice tree explorer
" Last Change:  9 september 2006
" Maintainer:   Martin Grenfell <martin_grenfell at msn.com>
let s:NERD_tree_version = '1.0beta1'


" Section: script init stuff {{{1
if exists("loaded_nerd_tree")
    finish
endif
let loaded_nerd_tree = 1
"Function: s:InitVariable() function {{{2
"This function is used to initialise a given variable to a given value. The
"variable is only initialised if it does not exist prior
"
"Args:
"var: the name of the var to be initialised
"value: the value to initialise var to
"
"Returns:
"1 if the var is set, 0 otherwise
function s:InitVariable(var, value)
    if !exists(a:var)
        exec 'let ' . a:var . ' = ' . "'" . a:value . "'"
        return 1
    endif
    return 0
endfunction

"Section: Init variable calls {{{2 
call s:InitVariable("g:NERDTreeWinSize", 30)
call s:InitVariable("g:NERDTreeIgnore", '\~$')
call s:InitVariable("g:NERDTreeShowHidden", 0)


" Section: Script level variable declaration{{{2
let s:escape_chars =  " `|\"~'#"
let s:NERDTreeWinName = '_NERD_tree_'

"init all the nerd tree markup 
let s:tree_vert = '|'
let s:tree_vert_last = '`'
let s:tree_wid = 2
let s:tree_wid_str = '  '
let s:tree_wid_strM1 = ' '
let s:tree_dir_open = '~'
let s:tree_dir_closed = '+'
let s:tree_file = '-'
let s:tree_markup_reg = '[ \-+~`|]'
let s:tree_markup_reg_neg = '[^ \-+~`|]'

"" chars to escape in file/dir names - TODO '+' ?
let s:escape_chars =  " `|\"~'#"

" Section: Command declaration{{{2
"init the command that users start the nerd tree with 
command! -n=0 -complete=dir NERDTree :call s:InitNerdTree(expand("%:p:h"))
command! -n=0 -complete=dir NERDTreeToggle :call s:Toggle(expand("%:p:h"))

"SECTION: Classes {{{1
"============================================================
"CLASS: oTreeNode {{{2
"============================================================
let s:oTreeNode = {} 
"FUNCTION: oTreeNode.New {{{3 
"Returns a new TreeNode object with the given path and parent
"
"Args:
"fullpath: the full filesystem path to the file/dir that the node represents
"parent: the parent TreeNode to this one, or {} if this node has no parent
function s:oTreeNode.New(fullpath, parent) dict
    let newTreeNode = copy(self)
    let fullpath = a:fullpath

    let newTreeNode.parent = a:parent

    if !has("unix") 
        let fullpath = s:WinToUnixPath(fullpath)
    endif

    if isdirectory(fullpath)
        let newTreeNode.filename = ''
        let newTreeNode.dirpath = substitute(fullpath, '.\+\(.*\)/$',  '\1', '')
        let newTreeNode.isDirectory = 1
        let newTreeNode.isOpen = 0
        let newTreeNode.children = []
    elseif filereadable(fullpath)
        let newTreeNode.filename = substitute(fullpath, '.*/',  '', '')
        let newTreeNode.dirpath = substitute(fullpath, '\(.*\)/.*',  '\1', '')
        let newTreeNode.isDirectory = 0
    else
        throw "Invalid Arguments Exception. Invalid path = " . fullpath
    endif

    return newTreeNode
endfunction

"FUNCTION: oTreeNode.GetFilename(esc) {{{3 
"returns the filename for this treenode.
"ARGS:
"esc: if 1, all the tricky chars for file name are escaped 
function s:oTreeNode.GetFilename(esc)
    if a:esc = 1
        return escape(a:esc, s:escape_chars)
    else
        return self.filename
    endif
endfunction

"FUNCTION: oTreeNode.GetLastPathSegment {{{3 
"Gets last part of the fullpath for this node... eg if this node represents
"/home/marty/foo.txt then this will return foo.txt. Or marty/ if the node
"represents /home/marty/
function s:oTreeNode.GetLastPathSegment()
    if self.isDirectory == 1
        return substitute(self.dirpath, '.*/', '', '') . '/'
    else
        return self.filename
    endif
endfunction

"FUNCTION: oTreeNode.GetFullPath(esc) {{{3 
"returns the full path to this tree's file node
"ARGS:
"esc: if 1, all the tricky chars for file name are escaped 
function s:oTreeNode.GetFullPath(esc) dict
    let toReturn = self.dirpath
    if toReturn !~ '/$'
        let toReturn = toReturn . '/'
    endif
    if self.isDirectory == 0
        let toReturn = toReturn . self.filename
    endif

    if a:esc == 1
        let toReturn = escape(toReturn, s:escape_chars)
    endif
    return toReturn
endfunction
"FUNCTION: oTreeNode.Open {{{3 
"Assumes this node is a directory node.
"Reads in all this nodes children
"
"Return: the number of child nodes read
function s:oTreeNode.Open() dict
    if self.isDirectory != 1
        throw "Illegal Operation. Cannot perform oTreeNode.Open() on a file node"
    endif

    let self.isOpen = 1
    if self.children == []
        return self.InitChildren()
    else
        return 0
    endif
endfunction
"FUNCTION: oTreeNode.Refresh {{{3 
"Assumes this node is a directory node.
"
"Alias for self.InitChildren()
"
"Return: the number of child nodes read
function s:oTreeNode.Refresh() dict
    return self.InitChildren()
endfunction
"FUNCTION: oTreeNode.InitChildren {{{3 
"Assumes this node is a directory node.
"Removes all childen from this node and re-reads them
"
"Return: the number of child nodes read
function s:oTreeNode.InitChildren() dict
    "remove all the current child nodes 
    let self.children = []

    "get an array of all the files in the nodes dir 
    let filesStr = globpath(self.dirpath, '*') . "\n" . globpath(self.dirpath, '.*')
    let files = split(filesStr, "\n")

    let invalidFilesFound = 0
    for i in files

        "filter out the .. and . directories 
        if i !~ '\.\.$' && i !~ '\.$'


            let unixpath = s:WinToUnixPath(i) 
            let lastPathComponent = substitute(unixpath, '.*/', '', '')

            "filter out the user specified dirs to ignore 
            if lastPathComponent !~ g:NERDTreeIgnore

                "dont show hidden files unless instructed to 
                if g:NERDTreeShowHidden == 1 || lastPathComponent !~ '^\.'

                    "put the next file in a new node and attach it 
                    try
                        let newNode = s:oTreeNode.New(i, self)
                        call add(self.children,newNode)
                    catch /^Invalid Arguments/
                        let invalidFilesFound = 1
                    endtry
                endif

            endif
        endif
    endfor
    if invalidFilesFound
        echo "Warning: some files could not be loaded into the NERD tree"
    endif
    return len(self.children)
endfunction
"FUNCTION: oTreeNode.Close {{{3 
"Assumes this node is a directory node.
"Closes this directory, removes all the child nodes.
function s:oTreeNode.Close() dict
    if self.isDirectory != 1
        throw "Illegal Operation. Cannot perform oTreeNode.Close() on a file node"
    endif
    let self.isOpen = 0
endfunction
"FUNCTION: oTreeNode.ToggleOpen {{{3 
"Assumes this node is a directory node.
"Opens this directory if it is closed and vice versa
function s:oTreeNode.ToggleOpen() dict
    if self.isDirectory != 1
        throw "Illegal Operation. Cannot perform oTreeNode.Close() on a file node"
    endif
    if self.isOpen == 1
        call self.Close()
    else
        call self.Open()
    endif
endfunction

"FUNCTION: oTreeNode.FindNodeByAbsPath(path) {{{3 
"Will find one of the children (recursively) that has a full path of a:path
"
"Args:
"path: the full path of the desired node
function s:oTreeNode.FindNodeByAbsPath(path) dict
    let path = escape(a:path, s:escape_chars)
    let fullpath = self.GetFullPath(1)

    if path == fullpath
        return self
    endif
    if stridx(path, fullpath, 0) == -1
        return {}
    endif

    if self.isDirectory == 1
        for i in self.children
            let retVal = i.FindNodeByAbsPath(a:path)
            if retVal != {}
                return retVal
            endif
        endfor
    endif
    return {}
endfunction
"FUNCTION: oTreeNode.TransplantChild(newNode) {{{3 
"Replaces the child of this with the given node (where the child node's full
"path matches a:newNode's fullpath). The search for the matching node is
"non-recursive
"
"Arg:
"newNode: the node to graft into the tree 
function s:oTreeNode.TransplantChild(newNode) dict
    for i in range(0, len(self.children)-1)
        if self.children[i].GetFullPath(1) == a:newNode.GetFullPath(1)
            let self.children[i] = a:newNode
            let a:newNode.parent = self
            break
        endif
    endfor
endfunction
"FUNCTION: oTreeNode.Equals(treenode) {{{3 
"
"Compares this treenode to the input treenode and returns 1 if they are the
"same node.
"
"Use this method instead of ==  because sometimes when the treenodes contain
"many children, vim seg faults when doing ==
"
"Args:
"treenode: the other treenode to compare to
function s:oTreeNode.Equals(treenode) dict
    return self.GetFullPath(0) == a:treenode.GetFullPath(0)
endfunction
"FUNCTION: oTreeNode.FindSibling(direction) {{{3 
"
"Finds the next sibling for this node in the indicated direction  
"
"Args:
"direction: 0 if you want to find the previous sibling, 1 for the next sibling
"
"Return:
"a treenode object or {} if no sibling could be found
function s:oTreeNode.FindSibling(direction) dict
    for i in range(0, len(self.parent.children)-1)
        if self.parent.children[i].Equals(self)
            let siblingIndx = a:direction == 1 ? i+1 : i-1
            if siblingIndx > len(self.parent.children)-1 || siblingIndx < 0
                return {}
            else
                return self.parent.children[siblingIndx]
            endif
        endif
    endfor

    return {}
endfunction
"FUNCTION: s:BufInWindows(bnum){{{1
"[[STOLEN FROM VTREEEXPLORER.VIM]]
"Determine the number of windows open to this buffer number. 
"Care of Yegappan Lakshman.  Thanks! 
"
"Args:
"bnum: the subject buffers buffer number
function s:BufInWindows(bnum) 
    let cnt = 0
    let winnum = 1
    while 1
        let bufnum = winbufnr(winnum)
        if bufnum < 0
            break
        endif
        if bufnum == a:bnum
            let cnt = cnt + 1
        endif
        let winnum = winnum + 1
    endwhile

    return cnt
endfunction " >>>
"FUNCTION: s:CloseTree() {{{1 
"Closes the NERD tree window
function s:CloseTree()
    let winnr = s:GetTreeWinNum()
    if winnr != -1
        execute winnr . " wincmd w"
        close
        execute "wincmd p"
    endif
endfunction
"FUNCTION: s:CreateTreeWin() {{{1 
"Inits the NERD tree window. ie. opens it, sizes it, sets all the local
"options etc
function s:CreateTreeWin()
    "create the nerd tree window 
    let splitLocation = "topleft "
    let splitMode = "vertical " 
    let splitSize = g:NERDTreeWinSize 
    let t:NERDTreeWinName = localtime() . s:NERDTreeWinName
    let cmd = splitLocation . splitMode . splitSize . ' new ' . t:NERDTreeWinName
    silent! execute cmd


    setl winfixwidth


    " throwaway buffer options
    setlocal noswapfile
    setlocal buftype=nowrite
    setlocal bufhidden=delete 
    setlocal nowrap
    setlocal foldcolumn=0

    setlocal nobuflisted
    setlocal nospell
    iabc <buffer>

    " syntax highlighting
    if has("syntax") && exists("g:syntax_on") && !has("syntax_items")
        syn match treeHlp  #^" .*#

        execute "syn match treePrt  #" . s:tree_vert      . "#"
        execute "syn match treePrt  #" . s:tree_vert_last . "#"
        execute "syn match treePrt  #" . s:tree_file      . "#"

        syn match treeLnk       #[^-| `].* -> # 
        syn match treeDir       #[^-| `].*/\([ {}]\{4\}\)*$# contains=treeLnk
        syn match treeCWD       #^/.*$# 
        syn match treeOpenable #+\<#
        syn match treeOpenable #\~\<#
        syn match treeOpenable #\~\.#
        syn match treeOpenable #+\.#

        hi def link treePrt Normal
        hi def link treeHlp Special
        hi def link treeDir Directory
        hi def link treeCWD Statement
        hi def link treeLnk Title
        hi def link treeOpenable Title
    endif

    " for line continuation
    let cpo_save1 = &cpo
    set cpo&vim

    call s:BindMappings()
endfunction
"FUNCTION: s:DrawTree {{{1 
"Draws the given node recursively
"
"Args:
"curNode: the node that is being rendered with this call
"depth: the current depth in the tree for this call
"drawText: 1 if we should actually draw the line for this node (if 0 then the
"child nodes are rendered only)
"vertMap: a binary array that indicates whether a vertical bar should be draw
"for each depth in the tree
"isLastChild:true if this curNode is the last child of its parent
function s:DrawTree(curNode, depth, drawText, vertMap, isLastChild)
    if a:drawText == 1

        let treeParts = ''
        if a:depth > 1
            for j in a:vertMap[0:len(a:vertMap)-2]
                if j == 1
                    let treeParts = treeParts . s:tree_vert . s:tree_wid_strM1
                else
                    let treeParts = treeParts . s:tree_wid_str
                endif
            endfor
        endif

        if a:isLastChild
            let treeParts = treeParts . s:tree_vert_last
        else
            let treeParts = treeParts . s:tree_vert 
        endif


        if a:curNode.isDirectory
            if a:curNode.isOpen
                let treeParts = treeParts . s:tree_dir_open
            else
                let treeParts = treeParts . s:tree_dir_closed
            endif
        else
            let treeParts = treeParts . s:tree_file
        endif
        let line = treeParts . a:curNode.GetLastPathSegment()

        call setline(line(".")+1, line)
        normal j
    endif

    if a:curNode.isDirectory == 1 && a:curNode.isOpen == 1 && len(a:curNode.children) > 0
        let lastIndx = len(a:curNode.children)-1
        if lastIndx > 0
            for i in a:curNode.children[0:lastIndx-1]
                call s:DrawTree(i, a:depth + 1, 1, add(copy(a:vertMap), 1), 0)
            endfor
        endif
        call s:DrawTree(a:curNode.children[lastIndx], a:depth + 1, 1, add(copy(a:vertMap), 0), 1)
    endif
endfunction


"FUNCTION: s:DumpHelp {{{1 
"prints out the quick help 
function s:DumpHelp()
    let old_h = @h
    if t:treeShowHelp == 1
        let @h=   "\" <ret>       = same as 'o' below\n"
        let @h=@h."\" double click= same as 'o' below\n"
        let @h=@h."\" middle click= same as '<tab>' below\n"
        let @h=@h."\" o           = (file) open in previous window\n"
        let @h=@h."\" o           = (dir) expand dir tree node\n"
        let @h=@h."\" <tab>       = (file) open in a new window\n"
        let @h=@h."\" x           = close the current dir\n"
        let @h=@h."\" C           = chdir top of tree to cursor dir\n"
        let @h=@h."\" u           = move up a dir\n"
        let @h=@h."\" U           = move up a dir, preserve current tree\n"
        let @h=@h."\" r           = refresh cursor dir\n"
        let @h=@h."\" R           = refresh top dir\n"
        let @h=@h."\" p           = move cursor to parent directory\n"
        let @h=@h."\" s           = move cursor to next sibling node\n"
        let @h=@h."\" S           = move cursor to previous sibling node\n"
        let @h=@h."\" D           = toggle show hidden (currently: " .  (g:NERDTreeShowHidden ? "on" : "off") . ")\n"
        let @h=@h."\" ?           = toggle help\n"
    else
        let @h="\" ? : toggle help\n"
    endif

    put h

    let @h = old_h
endfunction
"FUNCTION: s:FindNodeLineNumber(path){{{1
"Finds the line number for the given tree node
"
"Args:
"treenode: the node to find the line no. for
function s:FindNodeLineNumber(treenode) 
    "if the node is the root then return the root line no. 
    if t:currentRoot.Equals(a:treenode)
        return s:FindRootNodeLineNumber()
    endif

    let totalLines = line("$")

    "the path components we have matched so far 
    let pathcomponents = [substitute(t:currentRoot.GetFullPath(0), '/ *$', '', '')]
    "the index of the component we are searching for 
    let curPathComponent = 1

    let fullpath = a:treenode.GetFullPath(0)


    let lnum = s:FindRootNodeLineNumber()
    while lnum > 0
        let lnum = lnum + 1
        "have we reached the bottom of the tree? 
        if lnum == totalLines+1
            return -1
        endif

        let curLine = getline(lnum)

        let indent = match(curLine,s:tree_markup_reg_neg) / s:tree_wid
        if indent == curPathComponent
            let curLine = s:StripMarkupFromLine(curLine, 1)

            let curPath =  join(pathcomponents, '/') . '/' . curLine
            if stridx(fullpath, curPath, 0) == 0 
                if fullpath == curPath || strpart(fullpath, len(curPath)-1,1) == '/'
                    let curLine = substitute(curLine, '/ *$', '', '')
                    call add(pathcomponents, curLine)
                    let curPathComponent = curPathComponent + 1

                    if fullpath == curPath
                        return lnum
                    endif
                endif
            endif
        endif
    endwhile
    return -1
endfunction
"FUNCTION: s:FindRootNodeLineNumber(path){{{1
"Finds the line number of the root node  
function s:FindRootNodeLineNumber() 
    let rootLine = 1
    while getline(rootLine) !~ '^/'
        let rootLine = rootLine + 1
    endwhile
    return rootLine
endfunction

"FUNCTION: s:GetParentLineNum(ln) {{{1 
"gets the line number of the parent node for the node on the given line  
"
"Args:
"ln: the line to get the parent node for
function! s:GetParentLineNum(ln) 
    let line = getline(a:ln)

    " in case called from outside the tree
    if line =~ '^[/".]' || line =~ '^$'
        return ""
    endif

    "get the indent level for the file (i.e. how deep in the tree it is) 
    "let indent = match(line,'[^-| `]') / s:tree_wid
    let indent = match(line, s:tree_markup_reg_neg) / s:tree_wid


    "remove the tree parts and the leading space 
    let curFile = s:StripMarkupFromLine(line, 0)


    let dir = ""
    let lnum = a:ln
    while lnum > 0
        let lnum = lnum - 1
        let curLine = getline(lnum)

        "have we reached the top of the tree? 
        if curLine =~ '^/'
            return lnum
        endif
        if curLine =~ '/$'
            let lpindent = match(curLine,s:tree_markup_reg_neg) / s:tree_wid
            if lpindent < indent
                return lnum
            endif
        endif
    endwhile
    "let curFile = dir . curFile
    "return curFile
endfunction 
"FUNCTION: s:GetPath(ln) {{{1 
"Gets the full path to the node that is rendered on the given line number
"
"Args:
"ln: the line number to get the path for
function! s:GetPath(ln) 
    let line = getline(a:ln)

    " in case called from outside the tree
    if line =~ '^[/".]' || line =~ '^$'
        return ""
    endif

    "get the indent level for the file (i.e. how deep in the tree it is) 
    "let indent = match(line,'[^-| `]') / s:tree_wid
    let indent = match(line, s:tree_markup_reg_neg) / s:tree_wid


    "remove the tree parts and the leading space 
    let curFile = s:StripMarkupFromLine(line, 0)

    let wasdir = 0
    if curFile =~ '/$' 
        let wasdir = 1
    endif
    let curFile = substitute (curFile,' -> .*',"","") " remove link to
    if wasdir == 1
        let curFile = substitute (curFile, '/\?$', '/', "")
    endif


    let dir = ""
    let lnum = a:ln
    while lnum > 0
        let lnum = lnum - 1
        let curLine = getline(lnum)

        "have we reached the top of the tree? 
        if curLine =~ '^/'
            let sd = substitute (curLine, '[ ]*$', "", "")
            let dir = sd . dir
            break
        endif
        if curLine =~ '/$'
            let lpindent = match(curLine,s:tree_markup_reg_neg) / s:tree_wid
            if lpindent < indent
                let indent = indent - 1
                let sd = substitute (curLine, '^' . s:tree_markup_reg . '*',"","") " rm tree parts
                let sd = substitute (sd, ' -> .*','/',"") " replace link to with /

                " remove leading escape
                let sd = substitute (sd,'^\\', "", "")

                let dir = sd . dir
                continue
            endif
        endif
    endwhile
    let curFile = dir . curFile
    return curFile
endfunction 
"FUNCTION: s:GetSelectedNode() {{{1 
"gets the treenode that the cursor is currently over
function! s:GetSelectedNode() 
    let fullpath = s:GetPath(line("."))
    return t:currentRoot.FindNodeByAbsPath(fullpath)
endfunction

"FUNCTION: s:GetTreeWinNum()"{{{1
"gets the nerd tree window number for this tab
function! s:GetTreeWinNum() 
    if exists("t:NERDTreeWinName")
        return bufwinnr(t:NERDTreeWinName)
    else
        return -1
    endif
endfunction
"FUNCTION: s:InitNerdTree(dir) {{{1 
"Initialized the NERD tree, where the root will be initialized with the given
"directory
"
"Arg:
"dir: the dir to init the root with
function s:InitNerdTree(dir)
    if a:dir != ""
        try
            execute "lcd " . escape (a:dir, s:escape_chars)
        catch
            echo "NERD_Tree: Error changing to directory: " . a:dir
            return
        endtry
    endif

    let t:currentRoot = s:oTreeNode.New(a:dir, {})
    call t:currentRoot.Open()
    let t:treeShowHelp = 0

    if exists("t:NERDTreeWinSize")
        unlet t:NERDTreeWinSize
    endif
    call s:CreateTreeWin()

    call s:RenderTree()
endfunction

"FUNCTION: s:OpenFileSplit(treenode)"{{{1
"Open the file represented by the given node in a new window.  If a directory
"is selected then no action is taken 
"
"ARGS:
"treenode: the file node to open
function! s:OpenFileSplit(treenode) 
    "bail out if they wanna open a dir 
    if a:treenode.isDirectory
        return
    endif

    exe s:GetTreeWinNum() . 'wincmd w'

    " Save the user's settings for splitbelow and splitright
    let savesplitbelow=&splitbelow
    let savesplitright=&splitright

    " Figure out how to do the split based on the user's preferences.
    " We want to split to the (left,right,top,bottom) of the explorer
    " window, but we want to extract the screen real-estate from the
    " window next to the explorer if possible.
    "
    " 'there' will be set to a command to move from the split window
    " back to the explorer window
    "
    " 'back' will be set to a command to move from the explorer window
    " back to the newly split window
    "
    " 'right' and 'below' will be set to the settings needed for
    " splitbelow and splitright IF the explorer is the only window.
    "
    if exists("g:treeExplVertical")
        let there="wincmd h"
        let back ="wincmd l"
        let right=1
        let below=0
    else
        let there="wincmd k"
        let back ="wincmd j"
        let right=0
        let below=1
    endif

    " Get the window number of the explorer window
    let n = s:GetTreeWinNum()

    " Attempt to go to adjacent window
    exec(back)

    let onlyOneWin = n==winnr()

    " If no adjacent window, set splitright and splitbelow appropriately
    if onlyOneWin
        let &splitright=right
        let &splitbelow=below
    else
        " found adjacent window - invert split direction
        let &splitright=!right
        let &splitbelow=!below
    endif

    " Create a variable to use if splitting vertically
    let splitMode = ""
    if onlyOneWin
        let splitMode = "vertical"
    endif

    " Open the new window
    exec("silent " . splitMode." sp " . a:treenode.GetFullPath(1))

    " resize the explorer window if it is larger than the requested size
    exec(there)

    if g:NERDTreeWinSize =~ '[0-9]\+' && winheight("") > g:NERDTreeWinSize
        exec("silent vertical resize ".g:NERDTreeWinSize)
    endif

    normal 

    " Restore splitmode settings
    let &splitbelow=savesplitbelow
    let &splitright=savesplitright

endfunction 
"FUNCTION: s:PutCursorOnNode(treenode){{{1
"Places the cursor on the line number representing the given node
"
"Args:
"treenode: the node to put the cursor on
function s:PutCursorOnNode(treenode) 
    let ln = s:FindNodeLineNumber(a:treenode)
    if ln != -1
        call cursor(ln, col("."))
    endif
endfunction

"FUNCTION: s:RenderTree {{{1 
"The entry function for rendering the tree. Renders the root then calls
"s:DrawTree to draw the children of the root
"
"Args:
function s:RenderTree()
    execute s:GetTreeWinNum() . "wincmd w"

    setlocal modifiable

    "remember the top line of the buffer and the current line so we can
    "restore the view exactly how it was
    let curLine = line(".")
    let curCol = col(".")
    normal H
    let topLine = line(".")

    "delete all lines in the buffer (being careful not to clobber a register)  
	let save_y = @"
    silent! normal ggdG
	let @" = save_y


    call s:DumpHelp()

    "draw the header line  
    call setline(line(".")+1, t:currentRoot.GetFullPath(0))
    normal j
    call s:DrawTree(t:currentRoot, 0, 0, [], len(t:currentRoot.children) == 1)

    "restore the view 
    call cursor(topLine, 1)
    normal zt
    call cursor(curLine, curCol)

    setlocal nomodifiable

endfunction
"FUNCTION: s:StripMarkupFromLine(line){{{1
"returns the given line with all the tree parts stripped off
"
"Args:
"line: the subject line
"removeLeadingSpaces: 1 if leading spaces are to be removed (leading spaces =
"any spaces before the actual text of the node)
function s:StripMarkupFromLine(line, removeLeadingSpaces) 
    let line = a:line
    "remove the tree parts and the leading space 
    let line = substitute (line,"^" . s:tree_markup_reg . "*","","")

    let wasdir = 0
    if line =~ '/$' 
        let wasdir = 1
    endif
    let line = substitute (line,' -> .*',"","") " remove link to
    if wasdir == 1
        let line = substitute (line, '/\?$', '/', "")
    endif

    if a:removeLeadingSpaces
        let line = substitute (line, '^ *', '', '')
    endif

    return line
endfunction
"FUNCTION: s:Toggle(dir) {{{1 
"Toggles the NERD tree. I.e the NERD tree is open, it is closed, if it is
"closed it is restored or initialized (if it doesnt exist)     
"
"Args:
"dir: the full path for the root node (is only used if the NERD tree is being
"initialized.
function s:Toggle(dir)
    if exists("t:currentRoot")
        if s:GetTreeWinNum() == -1
            execute "lcd " . t:currentRoot.GetFullPath(1)
            call s:CreateTreeWin()
            call s:RenderTree()
        else
            call s:CloseTree()
        endif
    else
        call s:InitNerdTree(a:dir)
    endif
endfunction
"FUNCTION: s:WinToUnixPath(path){{{1
"Takes in a windows path and returns the unix equiv
"
"Args:
"path: the windows path to convert
function s:WinToUnixPath(path) 
    let toReturn = a:path

    "remove the x:\ of the front
    let toReturn = substitute(toReturn, '^.*:\', '/', "")

    "convert all \ chars to / 
    let toReturn = substitute(toReturn, '\', '/', "g")

    return toReturn
endfunction
"SECTION: NERD tree interface bindings {{{1
"============================================================
"FUNCTION: s:BindMappings() {{{2
function s:BindMappings()
    " set up mappings and commands for this buffer
    nnoremap <buffer> <cr> :call <SID>Activate()<cr>
    nnoremap <buffer> o :call <SID>Activate()<cr>
    nnoremap <buffer> <tab> :call <SID>OpenEntrySplit()<cr>
    nnoremap <buffer> <2-leftmouse> :call <SID>Activate()<cr>
    nnoremap <buffer> <middlerelease> :call <SID>OpenEntrySplit()<cr>
    nnoremap <buffer> <leftrelease> :call <SID>CheckForActivate()<cr>

    nnoremap <buffer> U :call <SID>UpDir(1)<cr>
    nnoremap <buffer> u :call <SID>UpDir(0)<cr>
    nnoremap <buffer> C :call <SID>ChRoot()<cr>

    nnoremap <buffer> R :call <SID>RefreshRoot()<cr>
    nnoremap <buffer> r :call <SID>RefreshCurrent()<cr>

    nnoremap <buffer> ? :call <SID>DisplayHelp()<cr>
    nnoremap <buffer> D :call <SID>ToggleShowHidden()<cr>
    nnoremap <buffer> x :call <SID>CloseCurrentDir()<cr>

    nnoremap <buffer> p :call <SID>JumpToParent()<cr>
    nnoremap <buffer> s :call <SID>JumpToSibling(1)<cr>
    nnoremap <buffer> S :call <SID>JumpToSibling(0)<cr>
endfunction
"FUNCTION: s:Activate() {{{2
"If the current node is a file, open it in the previous window (or a new one
"if the previous is modified). If it is a directory then it is opened.
function s:Activate()
    let treenode = s:GetSelectedNode()
    if treenode == {} 
        echo "NERD_tree: cannot open selected entry"
        return
    endif

    if treenode.isDirectory
        call treenode.ToggleOpen()
        call s:RenderTree()
        call s:PutCursorOnNode(treenode)
    else
        let oldwin = winnr()
        wincmd p
        if oldwin == winnr() || (&modified && s:BufInWindows(winbufnr(winnr())) < 2)
            wincmd p
            call s:OpenFileSplit(treenode)
        else
            exec ("edit " . treenode.GetFullPath(1))
        endif
    endif
endfunction
"FUNCTION: s:CheckForActivate() {{{2
"Checks if the click should open the current node, if so then activate() is
"called (directories are automatically opened if the symbol beside them is
"clicked)
function s:CheckForActivate()
    let startToCur = strpart(getline(line(".")), 0, col("."))
    
    let reg = '^' . s:tree_markup_reg .'*[' . s:tree_dir_open . s:tree_dir_closed . ']$'
    if startToCur =~ reg
        call s:Activate()
    endif
endfunction
" FUNCTION: s:OpenEntrySplit() {{{2
" Opens the currently selected file from the explorer in a
" new window 
function! s:OpenEntrySplit() 
    let treenode = s:GetSelectedNode()
    if treenode != {}
        call s:OpenFileSplit(treenode)
    else
        echo "NERD_tree: cannot open selected entry"
    endif
endfunction 
"FUNCTION: s:UpDir(keepState) {{{2
"moves the tree up a level
"
"Args:
"keepState: 1 if the current root should be left open when the tree is
"re-rendered
function! s:UpDir(keepState) 

    let cwd = getcwd()
    if cwd == "/" || cwd =~ '^[^/]..$'
        echo "NERD_tree: already at top dir"
    else
        lcd ..

        if !a:keepState
            call t:currentRoot.Close()

        endif

        let oldRoot = t:currentRoot

        if empty(t:currentRoot.parent)
            let newRoot = s:oTreeNode.New(getcwd(), {})
            call newRoot.Open()
            call newRoot.TransplantChild(t:currentRoot)
            let t:currentRoot = newRoot
        else
            let t:currentRoot = t:currentRoot.parent

        endif

        call s:RenderTree()
        call s:PutCursorOnNode(oldRoot)
    endif

endfunction
" FUNCTION: s:RefreshRoot() {{{2
" Reloads the current root. All nodes below this will be lost and the root dir
" will be reloaded.
function! s:RefreshRoot() 
    call t:currentRoot.Refresh()
    call s:RenderTree()
endfunction
" FUNCTION: s:RefreshCurrent() {{{2
" refreshes the root for the current node
function! s:RefreshCurrent() 
    let treenode = s:GetSelectedNode()
    if treenode == {} 
        echo "NERD_tree: cannot refresh selected dir"
        return
    endif

    let curDir = treenode.dirpath . '/'
    let parentNode = t:currentRoot.FindNodeByAbsPath(curDir)
    if parentNode == {}
        echo "NERD_tree: cannot refresh selected dir"
        return
    endif

    call parentNode.Refresh()
    call s:RenderTree()
endfunction
" FUNCTION: s:DisplayHelp() {{{2
" toggles the help display
function s:DisplayHelp() 
    let t:treeShowHelp = t:treeShowHelp ? 0 : 1
    call s:RenderTree()
endfunction
" FUNCTION: s:ChRoot() {{{2
" changes the current root to the selected one
function s:ChRoot() 
    let treenode = s:GetSelectedNode()
    if treenode == {} 
        echo "NERD_tree: cannot change root node"
        return
    elseif treenode.isDirectory == 0
        echo "NERD_tree: cannot change root node"
        return
    endif

    if treenode.isOpen == 0
        call treenode.Open()
    endif

    execute "lcd " treenode.GetFullPath(1)

    let t:currentRoot = treenode
    call s:RenderTree()
endfunction
" FUNCTION: s:ToggleShowHidden() {{{2
" toggles the display of hidden files
function s:ToggleShowHidden() 
    let g:NERDTreeShowHidden = !g:NERDTreeShowHidden
    call t:currentRoot.Refresh()
    call s:RenderTree()
endfunction
" FUNCTION: s:CloseCurrentDir() {{{2
" closes the parent dir of the current node
function s:CloseCurrentDir() 
    let treenode = s:GetSelectedNode()
    let parent = treenode.parent
    if parent.GetFullPath(0) == t:currentRoot.GetFullPath(0)
        echo "NERDTree: cannot close tree root"
    else
        let linenum = s:GetParentLineNum(line("."))
        call treenode.parent.Close()
        call s:RenderTree()
        call cursor(linenum, col("."))
    endif
endfunction
" FUNCTION: s:JumpToParent() {{{2
" moves the cursor to the parent of the current node
function s:JumpToParent() 
    let currentNode = s:GetSelectedNode()
    if !empty(currentNode)
        if !empty(currentNode.parent) 
            call s:PutCursorOnNode(currentNode.parent)
        else
            echo "NERDTree: cannot jump to parent"
        endif
    else
        echo "NERDTree: put the cursor on a node first"
    endif
endfunction
" FUNCTION: s:JumpToSibling() {{{2
" moves the cursor to the sibling of the current node in the given direction
"
" Args:
" forward: 1 if the cursor should move to the next sibling, 0 if it should
" move back to the previous sibling
function s:JumpToSibling(forward) 
    let currentNode = s:GetSelectedNode()
    if !empty(currentNode)
        let sibling = currentNode.FindSibling(a:forward)
        if !empty(sibling)
            call s:PutCursorOnNode(sibling)
        else
            echo "NERDTree: no sibling found"
        endif
    else
        echo "NERDTree: put the cursor on a node first"
    endif
endfunction
" Function: s:InstallDocumentation(full_name, revision)   {{{1
"   Install help documentation.
" Arguments:
"   full_name: Full name of this vim plugin script, including path name.
"   revision:  Revision of the vim script. #version# mark in the document file
"              will be replaced with this string with 'v' prefix.
" Return:
"   1 if new document installed, 0 otherwise.
" Note: Cleaned and generalized by guo-peng Wen.
"
" Note about authorship: this function was taken from the vimspell plugin
" which can be found at http://www.vim.org/scripts/script.php?script_id=465
"
function s:InstallDocumentation(full_name, revision)
    " Name of the document path based on the system we use:
    if has("vms")
         " No chance that this script will work with
         " VMS -  to much pathname juggling here.
         return 1
    elseif (has("unix"))
        " On UNIX like system, using forward slash:
        let l:slash_char = '/'
        let l:mkdir_cmd  = ':silent !mkdir -p '
    else
        " On M$ system, use backslash. Also mkdir syntax is different.
        " This should only work on W2K and up.
        let l:slash_char = '\'
        let l:mkdir_cmd  = ':silent !mkdir '
    endif

    let l:doc_path = l:slash_char . 'doc'
    let l:doc_home = l:slash_char . '.vim' . l:slash_char . 'doc'

    " Figure out document path based on full name of this script:
    let l:vim_plugin_path = fnamemodify(a:full_name, ':h')
    let l:vim_doc_path    = fnamemodify(a:full_name, ':h:h') . l:doc_path
    if (!(filewritable(l:vim_doc_path) == 2))
         "Doc path: " . l:vim_doc_path
        call s:NerdEcho("Doc path: " . l:vim_doc_path, 0)
        execute l:mkdir_cmd . '"' . l:vim_doc_path . '"'
        if (!(filewritable(l:vim_doc_path) == 2))
            " Try a default configuration in user home:
            let l:vim_doc_path = expand("~") . l:doc_home
            if (!(filewritable(l:vim_doc_path) == 2))
                execute l:mkdir_cmd . '"' . l:vim_doc_path . '"'
                if (!(filewritable(l:vim_doc_path) == 2))
                    " Put a warning:
                    echo "Unable to open documentation directory"
                    echo "type :help add-local-help for more information."
                    echo l:vim_doc_path
                    return 0
                endif
            endif
        endif
    endif

    " Exit if we have problem to access the document directory:
    if (!isdirectory(l:vim_plugin_path) || !isdirectory(l:vim_doc_path) || filewritable(l:vim_doc_path) != 2)
        return 0
    endif

    " Full name of script and documentation file:
    let l:script_name = fnamemodify(a:full_name, ':t')
    let l:doc_name    = fnamemodify(a:full_name, ':t:r') . '.txt'
    let l:plugin_file = l:vim_plugin_path . l:slash_char . l:script_name
    let l:doc_file    = l:vim_doc_path    . l:slash_char . l:doc_name

    " Bail out if document file is still up to date:
    if (filereadable(l:doc_file) && getftime(l:plugin_file) < getftime(l:doc_file))
        return 0
    endif

    " Prepare window position restoring command:
    if (strlen(@%))
        let l:go_back = 'b ' . bufnr("%")
    else
        let l:go_back = 'enew!'
    endif

    " Create a new buffer & read in the plugin file (me):
    setl nomodeline
    exe 'enew!'
    exe 'r ' . l:plugin_file

    setl modeline
    let l:buf = bufnr("%")
    setl noswapfile modifiable

    norm zR
    norm gg

    " Delete from first line to a line starts with
    " === START_DOC
    1,/^=\{3,}\s\+START_DOC\C/ d

    " Delete from a line starts with
    " === END_DOC
    " to the end of the documents:
    /^=\{3,}\s\+END_DOC\C/,$ d

    " Remove fold marks:
    norm :%s/{{{[1-9]/    /

    " Add modeline for help doc: the modeline string is mangled intentionally
    " to avoid it be recognized by VIM:
    call append(line('$'), '')
    call append(line('$'), ' v' . 'im:tw=78:ts=8:ft=help:norl:')

    " Replace revision:
    "exe "normal :1s/#version#/ v" . a:revision . "/\<CR>"
    exe "normal :%s/#version#/ v" . a:revision . "/\<CR>"

    " Save the help document:
    exe 'w! ' . l:doc_file
    exe l:go_back
    exe 'bw ' . l:buf

    " Build help tags:
    exe 'helptags ' . l:vim_doc_path

    return 1
endfunction

" Section: Doc installation call {{{1
silent call s:InstallDocumentation(expand('<sfile>:p'), s:NERD_tree_version)
finish

"=============================================================================
" Section: The help file {{{1 
" Title {{{2
" ============================================================================
=== START_DOC
*NERD_tree.txt*   A plugin for navigating the filesystem        #version#


                           NERD_TREE REFERENCE MANUAL~





==============================================================================
CONTENTS {{{2                                         *NERD_tree-contents* 

    1.Intro...................................|NERD_tree|
    2.Functionality provided..................|NERD_tree-functionality|
        2.1 Commands..........................|NERD_tree-commands|
        2.2 NERD tree mappings................|NERD_tree-mappings|
    3.Customisation...........................|NERD_tree-customisation|
        3.1 Customisation summary.............|NERD_tree-cust-summary|
        3.2 Customisation details.............|NERD_tree-cust-details|
    4.TODO list...............................|NERD_tree-todo|
    5.The Author..............................|NERD_tree-author|
    6.Credits.................................|NERD_tree-credits|

==============================================================================
1. Intro {{{2                                                  *NERD_tree*

What is this "NERD_tree"??

The NERD tree allows you to explore your filesystem and to open files and
directories. It presents the filesystem to you in the form of a tree which you
manipulate with the keyboard and/or mouse.

What makes the "NERD_tree" so special?!

The NERD tree takes full advantage of vim 7's features to create and maintain
an OO model of the filesystem as you explore it. Every directory you go to
is stored in the NERD_tree model. This means that the state of directories
(either open or closed) is remembered and if you come back to a directory
hierarchy later in  your session, the directories in that hierarchy will be
opened and closed as you left them.  This can be very useful if you are
working within a framework that contains many directories of which, you only
care about the content of a few. This also minimises network traffic if you
are editing files on e.g. a samba share, as all filesystem information is
cached and is only re-read on demand.


==============================================================================
2. Functionality provided {{{2                       *NERD_tree-functionality*

------------------------------------------------------------------------------
2.1. Commands {{{3                                        *NERD_tree-commands*

:NERDTree       Opens a fresh NERD tree in the current directory. 

:NERDTreeToggle If a NERD tree already exists for this tab, it is reopened and
                rendered again.  If no NERD tree exists for this tab then this
                command acts the same as the :NERDTree command.



------------------------------------------------------------------------------
2.2. NERD tree Mappings {{{3                              *NERD_tree-mappings*

When the cursor is in the NERD tree window the following mappings may be used:

Key         Description~

o           If the cursor is on a file, this file is opened in the previous
            window. If the cursor is on a directory, the directory node is
            expanded in the tree.

<ret>       See 'o'

<tab>       Only applies to files. Opens the selected file in a new split
            window. 

x           Closes the directory that the cursor is inside.

C           Only applies to directories. Changes the current root of the NERD
            tree to the selected directory.

u           Change the root of the tree up one directory.

U           Same as 'u' except the old root is left open.

r           Refreshes the directory that the cursor is currently inside. 

R           Refreshes the current root of the tree.

p           Moves the cursor to parent directory of the directory it is
            currently inside.

s           Moves the cursor to next sibling of the current node.

S           Moves the cursor to previous sibling of the current node.

D           Toggles whether hidden files are shown or not.

?           Toggles the display of the quick help at the top of the tree.

The following mouse mappings are available:

Key             Description~

double click    Has the same effect as pressing 'o'

middle click    Has the same effect as pressing '<tab>'


Additionally, directories can be opened and closed by clicking the '+' and '~'
symbols on their left.
==============================================================================
3. Customisation {{{2                                *NERD_tree-customisation*


------------------------------------------------------------------------------
3.1. Customisation summary {{{3                       *NERD_tree-cust-summary*

The script provides the following options that can customise the behaviour the
NERD tree. These options should be set in your vimrc.

|loaded_nerd_tree|              Turns off the script

|NERDTreeWinSize|               Sets the window size when the NERD tree is
                                opened

|NERDTreeIgnore|                Tells the NERD tree which files to ignore.

|NERDTreeShowHidden|            Tells the NERD tree whether to display hidden
                                files on startup

------------------------------------------------------------------------------
3.2. Customisation details {{{3                       *NERD_tree-cust-details*

To enable any of the below options you should put the given line in your 
~/.vimrc

                                                            *loaded_nerd_tree*              
If this plugin is making you feel homicidal, it may be a good idea to turn it
off with this line in your vimrc: >
    let loaded_nerd_tree=1
<

------------------------------------------------------------------------------
                                                             *NERDTreeWinSize*               
This option is used to change the size of the NERD tree when it is loaded.
To use this option, stick the following line in your vimrc: >
    let NERDTreeWinSize=[New Win Size]
<

This option defaults to 30.

------------------------------------------------------------------------------
                                                              *NERDTreeIgnore*                
This option is used to specify which files the NERD tree should ignore. It
should be set to a regular expression. Then, any files matching this
expression are ignored. For example if you put the following line in your
vimrc: >
    let NERDTreeIgnore='.vim$\|\~$'
<
then all files ending in .vim or ~ will be ignored. 

This option defaults to '\~$'.

Note: to tell the NERD tree not to ignore any files you must use the following
line: >
    let NERDTreeIgnore='^$'
<

------------------------------------------------------------------------------
                                                          *NERDTreeShowHidden*            
This option tells vim whether to display hidden files by default. This option
can be dynamically toggled with the D mapping see |NERD_tree_mappings|.
Use the follow line to change this option: >
    let NERDTreeShowHidden=X
<
                                                       
This option defaults to 0.

==============================================================================
4. TODO list {{{2                                             *NERD_tree-todo*

Window manager integration?

More mappings to make it faster to use.

make mappings so it can open files in new tabs.

make it be able to edit the filesystem (create/delete directories and files)?

make it highlight read only files, symlinks etc.

make the position of the nerd tree customisable

make the mappings customisable?

dynamic hiding of tree content (eg, if you dont want to see a particular
directory for the rest of the current vim session, you can hide it with a
mapping)

make a mapping that toggles whether the NERDTreeIgnore is used.

make a command that can change the directory the nerd tree is in (so you can
go to another drive etc) 

Parameterise the nerd tree commands so they can take in a directory to start
from

==============================================================================
5. The Author {{{2                                         *NERD_tree-author*

The author of the NERD tree is a terrible terrible monster called Martyzilla
who gobbles up small children with milk and sugar for breakfast. He has an
odd love/hate relationship with computers (but monsters hate everything by
nature you know...) which can be awkward for him since he is a professional
computer nerd for a living.

He can be reached at martin_grenfell at msn.com. He would love to hear from
you, so feel free to send him suggestions and/or comments about this plugin
--- the worst he can do is slaughter you and stuff you in the fridge for
later.    

==============================================================================
6. Credits {{{2                                            *NERD_tree-credits*

Thanks to Tim Carey-Smith for testing/using the NERD tree from the first
pre-beta version, and for his many suggestions.

Thanks to Vigil for trying it out before the first release :) and suggesting
that mappings to open files in new tabs should be implemented.

Thanks to Nick Brettell for testing, fixing my spelling and suggesting i put a
    .. (up a directory)
line in the gui.


=== END_DOC
" vim: set ts=4 sw=4 foldmethod=marker foldmarker={{{,}}} foldlevel=2 fdc=4:
