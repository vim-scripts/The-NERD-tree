" vim global plugin that provides a nice tree explorer
" Last Change:  21 september 2006
" Maintainer:   Martin Grenfell <martin_grenfell at msn.com>
let s:NERD_tree_version = '1.0beta2'

"changelog since beta1:
"paramaterised :NERDTree and :NERDTreeToggle
"added t/T mappings
"added f mapping
"added g:NERDTreeSortDirs option
"symlinks are now highlighted
"when you toggle the nerd tree the cursor position is saved.. the screen state
"is restored exactly as when you closed it

"A help file is installed when the script is run for the first time. 
"Go :help NERD_tree.txt to see it.

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
call s:InitVariable("g:NERDTreeSortDirs", -1)


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

" chars to escape in file/dir names
let s:escape_chars =  " `|\"~'#"

" Section: NERD tree commands {{{1
"init the command that users start the nerd tree with 
command! -n=? -complete=dir NERDTree :call s:InitNerdTree('<args>')
command! -n=? -complete=dir NERDTreeToggle :call s:Toggle('<args>')
" Section: NERD tree auto commands {{{1
"
"Save the cursor position whenever we close the nerd tree
exec "autocmd BufWinLeave *". s:NERDTreeWinName ."* :call <SID>SaveScreenState()"

"SECTION: Classes {{{1
"============================================================
"CLASS: oTreeNode {{{2
"============================================================
let s:oTreeNode = {} 
let oTreeNode = s:oTreeNode
"FUNCTION: oTreeNode.CompareNodes {{{3 
"This is supposed to be a class level method but i cant figure out how to
"get func refs to work from a dict.. 
"
"A class level method that compares two nodes
"
"Args:
"n1, n2: the 2 nodes to compare
function s:CompareNodes(n1, n2)
    return a:n1.path.CompareTo(a:n2.path, g:NERDTreeSortDirs)
endfunction
"FUNCTION: oTreeNode.Close {{{3 
"Assumes this node is a directory node.
"Closes this directory, removes all the child nodes.
function s:oTreeNode.Close() dict
    if self.path.isDirectory != 1
        throw "Illegal Operation. Cannot perform oTreeNode.Close() on a file node"
    endif
    let self.isOpen = 0
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
    return self.path.GetPath(1) == a:treenode.path.GetPath(1)
endfunction
"FUNCTION: oTreeNode.FindNodeByAbsPath(path) {{{3 
"Will find one of the children (recursively) that has a full path of a:path
"
"Args:
"path: a path object
function s:oTreeNode.FindNodeByAbsPath(path) dict
    if a:path.Equals(self.path)
        return self
    endif
    if stridx(a:path.GetPath(1), self.path.GetPath(1), 0) == -1
        return {}
    endif

    if self.path.isDirectory
        for i in self.children
            let retVal = i.FindNodeByAbsPath(a:path)
            if retVal != {}
                return retVal
            endif
        endfor
    endif
    return {}
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
"FUNCTION: oTreeNode.GetChildDirs() {{{3 
"
"Assumes this node is a dir
"
"Returns an array of all children of this node that are directories
"
"Return:
"an array of directory treenodes
function s:oTreeNode.GetChildDirs() dict
    let toReturn = []
    for i in self.children
        if i.path.isDirectory
            call add(toReturn, i)
        endif
    endfor
    return toReturn
endfunction
"FUNCTION: oTreeNode.GetChildFiles() {{{3 
"
"Assumes this node is a dir
"
"Returns an array of all children of this node that are files
"
"Return:
"an array of file treenodes
function s:oTreeNode.GetChildFiles() dict
    let toReturn = []
    for i in self.children
        if i.path.isDirectory == 0
            call add(toReturn, i)
        endif
    endfor
    return toReturn
endfunction
"FUNCTION: oTreeNode.GetDisplayString() {{{3 
"
"Returns a string that specifies how the node should be represented as a
"string
"
"Return:
"a string that can be used in the view to represent this node
function s:oTreeNode.GetDisplayString() dict
    if self.path.isSymLink
        return self.path.GetLastPathComponent(1) . ' -> ' . self.path.symLinkDest
    else
        return self.path.GetLastPathComponent(1) 
    endif
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
    let filesStr = globpath(self.path.GetDir(), '*') . "\n" . globpath(self.path.GetDir(), '.*')
    let files = split(filesStr, "\n")

    let invalidFilesFound = 0
    for i in files

        "filter out the .. and . directories 
        if i !~ '\.\.$' && i !~ '\.$'


            let unixpath = s:WinToUnixPath(i) 
            let lastPathComponent = substitute(unixpath, '.*/', '', '')

            "filter out the user specified dirs to ignore 
            if !t:enableNERDTreeIgnore || lastPathComponent !~ g:NERDTreeIgnore

                "dont show hidden files unless instructed to 
                if g:NERDTreeShowHidden == 1 || lastPathComponent !~ '^\.'

                    "put the next file in a new node and attach it 
                    try
                        let path = s:oPath.New(i)
                        let newNode = s:oTreeNode.New(path, self)
                    catch /^Invalid Arguments/
                        let invalidFilesFound = 1
                    endtry
                endif

            endif
        endif
    endfor

    call self.SortChildren()

    if invalidFilesFound
        echo "Warning: some files could not be loaded into the NERD tree"
    endif
    return len(self.children)
endfunction
"FUNCTION: oTreeNode.New(path, parent) {{{3 
"Returns a new TreeNode object with the given path and parent
"
"Args:
"path: a path object representing the full filesystem path to the file/dir that the node represents
"parent: the parent TreeNode to this one, or {} if this node has no parent
function s:oTreeNode.New(path, parent) dict
    let newTreeNode = copy(self)
    let newTreeNode.path = a:path

    let newTreeNode.parent = a:parent
    if a:parent != {}
        call add(a:parent.children, newTreeNode)
    endif

    if newTreeNode.path.isDirectory
        let newTreeNode.isOpen = 0
        let newTreeNode.children = []
    endif

    return newTreeNode
endfunction
"FUNCTION: oTreeNode.Open {{{3 
"Assumes this node is a directory node.
"Reads in all this nodes children
"
"Return: the number of child nodes read
function s:oTreeNode.Open() dict
    if self.path.isDirectory != 1
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
"FUNCTION: oTreeNode.SortChildren {{{3 
"Assumes this node is a directory node.
"
"Sorts the children of this node according to alphabetical order and the
"directory priority.
"
function s:oTreeNode.SortChildren() dict
    let CompareFunc = function("s:CompareNodes")
    call sort(self.children, CompareFunc)
endfunction
"FUNCTION: oTreeNode.ToggleOpen {{{3 
"Assumes this node is a directory node.
"Opens this directory if it is closed and vice versa
function s:oTreeNode.ToggleOpen() dict
    if self.path.isDirectory != 1
        throw "Illegal Operation. Cannot perform oTreeNode.Close() on a file node"
    endif
    if self.isOpen == 1
        call self.Close()
    else
        call self.Open()
    endif
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
        if self.children[i].Equals(a:newNode)
            let self.children[i] = a:newNode
            let a:newNode.parent = self
            break
        endif
    endfor
endfunction
"CLASS: oPath {{{2
"============================================================
let s:oPath = {} 
let oPath = s:oPath
"FUNCTION: oPath.CompareTo() {{{3 
"
"Compares this oPath to the given path and returns 0 if they are equal, -1 if
"this oPath is "less than" the given path, or 1 if it is "greater".
"
"Two factors influence whether one path is greater than another:
"1. the path string itself
"2. the dirPriority flag
"
"Args:
"path: the path object to compare this to
"
"dirPriority: -1 if directories have lower priority than files, 1 if they have
"higher priority, 0 if the same.
"
"Return:
"1, -1 or 0
function s:oPath.CompareTo(path, dirPriority) dict
    let thisPath = self.GetPath(0)
    let thatPath = a:path.GetPath(0)

    if self.isDirectory == a:path.isDirectory || a:dirPriority == 0
        if thisPath == thatPath
            return 0
        elseif thisPath < thatPath
            return -1
        else
            return 1
        endif
    else
        if a:dirPriority == 1
            return (self.isDirectory == 0 ? 1 : -1)
        elseif a:dirPriority == -1
            return (self.isDirectory == 0 ? -1 : 1)
        endif
    endif

endfunction

"FUNCTION: oPath.CreatePath() {{{3 
function s:oPath.CreatePath(fullpath) dict
    if isdirectory(a:fullpath) || filereadable(a:fullpath)
        throw "Invalid arguments exception: path already exists"
    endif

    let fullpath = a:fullpath
    if !has("unix") 
        let fullpath = s:WinToUnixPath(fullpath)
    endif

    try 
        if fullpath =~ '\/$'
            call mkdir(fullpath)
        else
            if filereadable(fullpath)
                throw "File Exists Exception: '" . fullpath . "'"
            else
                call writefile([], fullpath)
            endif
        endif
    catch /.*/
        throw "Path Creating Exception. Could not create path node '" . a:fullpath . "'"
    endtry

    return s:oPath.New(fullpath)
endfunction
"FUNCTION: oPath.GetAbsPath() {{{3 
"
"Returns a string representing this path with all the symlinks resolved
"
"Return:
"string
function s:oPath.GetAbsPath() dict
    return resolve(self.GetPath(1))
endfunction
"FUNCTION: oPath.GetDir() {{{3 
"
"Gets the directory part of this path. If this path IS a directory then the
"whole thing is returned
"
"Return:
"string
function s:oPath.GetDir() dict
    if self.isDirectory
        return '/'. join(self.pathSegments, '/')
    else
        return '/'. join(self.pathSegments[0:len(self.pathSegments)-2], '/')
    endif
endfunction
"FUNCTION: oPath.GetFile() {{{3 
function s:oPath.GetFile() dict
    if self.isDirectory == 0
        return self.GetLastPathComponent(0)
    else
        return 
    endif
endfunction
"FUNCTION: oPath.GetLastPathComponent(dirSlash) {{{3 
function s:oPath.GetLastPathComponent(dirSlash) dict
    if empty(self.pathSegments)
        return ''
    endif
    let toReturn = self.pathSegments[ len(self.pathSegments)-1 ]
    if a:dirSlash && self.isDirectory
        let toReturn = toReturn . '/'
    endif
    return toReturn
endfunction
"FUNCTION: oPath.GetPath(esc) {{{3 
function s:oPath.GetPath(esc) dict
    let toReturn = '/' . join(self.pathSegments, '/')
    if self.isDirectory && toReturn != '/'
        let toReturn  = toReturn . '/'
    endif

    if a:esc
        let toReturn = escape(toReturn, s:escape_chars)
    endif
    return toReturn
endfunction
"FUNCTION: oPath.GetPathTrunk() {{{3 
function s:oPath.GetPathTrunk() dict
    return '/' . join(self.pathSegments[0:len(self.pathSegments)-2], '/')
endfunction
"FUNCTION: oPath.Equals() {{{3 
function s:oPath.Equals(path) dict
    return self.GetPath(1) == a:path.GetPath(1)
endfunction
"FUNCTION: oPath.New() {{{3 
function s:oPath.New(fullpath) dict
    let newPath = copy(self)
    let fullpath = a:fullpath

    if !has("unix") 
        let fullpath = s:WinToUnixPath(fullpath)
    endif

    let newPath.pathSegments = split(fullpath, '/')

    if isdirectory(fullpath)
        let newPath.isDirectory = 1
    elseif filereadable(fullpath)
        let newPath.isDirectory = 0
    else
        throw "Invalid Arguments Exception. Invalid path = " . fullpath
    endif

    "grab the last part of the path (minus the trailing slash) 
    let lastPathComponent = newPath.GetLastPathComponent(0)

    ""get the path to the new node with the parent dir fully resolved 
    let hardPath = resolve(newPath.GetPathTrunk()) . '/' . lastPathComponent

    ""if  the last part of the path is a symlink then flag it as such 
    let newPath.isSymLink = (resolve(hardPath) != hardPath)
    if newPath.isSymLink
        let newPath.symLinkDest = resolve(fullpath)
        if isdirectory(newPath.symLinkDest)
            let newPath.symLinkDest = newPath.symLinkDest . '/'
        endif
    endif

    return newPath
endfunction


" Section: General Functions {{{1
"============================================================
"FUNCTION: s:BufInWindows(bnum){{{2
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
"FUNCTION: s:CloseTree() {{{2 
"Closes the NERD tree window
function s:CloseTree()
    let winnr = s:GetTreeWinNum()
    if winnr != -1
        "let t:NERDTreeOldPos = getpos(".")
        execute winnr . " wincmd w"
        close
        execute "wincmd p"
    endif
endfunction
"FUNCTION: s:CreateTreeWin() {{{2 
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
"FUNCTION: s:DrawTree {{{2 
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


        if a:curNode.path.isDirectory
            if a:curNode.isOpen
                let treeParts = treeParts . s:tree_dir_open
            else
                let treeParts = treeParts . s:tree_dir_closed
            endif
        else
            let treeParts = treeParts . s:tree_file
        endif
        let line = treeParts . a:curNode.GetDisplayString()

        call setline(line(".")+1, line)
        normal j
    endif

    if a:curNode.path.isDirectory == 1 && a:curNode.isOpen == 1 && len(a:curNode.children) > 0
        let childNodesToDraw = a:curNode.children
        let lastIndx = len(childNodesToDraw)-1
        if lastIndx > 0
            for i in childNodesToDraw[0:lastIndx-1]
                call s:DrawTree(i, a:depth + 1, 1, add(copy(a:vertMap), 1), 0)
            endfor
        endif
        call s:DrawTree(childNodesToDraw[lastIndx], a:depth + 1, 1, add(copy(a:vertMap), 0), 1)
    endif
endfunction
"FUNCTION: s:DumpHelp {{{2 
"prints out the quick help 
function s:DumpHelp()
    let old_h = @h
    if t:treeShowHelp == 1
        let @h=   "\" <ret> = same as 'o' below\n"
        let @h=@h."\" o     = (file) open in previous window\n"
        let @h=@h."\" o     = (dir) expand dir tree node\n"
        let @h=@h."\" <tab> = (file) open in a new window\n"
        let @h=@h."\" t     = (file) open in a new tab\n"
        let @h=@h."\" T     = (file) open in a new tab, stay in current tab\n"
        let @h=@h."\" x     = close the current dir\n"
        let @h=@h."\" C     = chdir top of tree to cursor dir\n"
        let @h=@h."\" u     = move up a dir\n"
        let @h=@h."\" U     = move up a dir, preserve current tree\n"
        let @h=@h."\" r     = refresh cursor dir\n"
        let @h=@h."\" R     = refresh current root\n"
        let @h=@h."\" p     = move cursor to parent directory\n"
        let @h=@h."\" s     = move cursor to next sibling node\n"
        let @h=@h."\" S     = move cursor to previous sibling node\n"
        let @h=@h."\" D     = toggle show hidden (currently: " .  (g:NERDTreeShowHidden ? "on" : "off") . ")\n"
        let @h=@h."\" f     = toggle file filter (currently: " .  (t:enableNERDTreeIgnore ? "on" : "off") . ")\n"
        let @h=@h."\" ?     = toggle help\n"

        let @h=@h."\" double click = same as 'o'\n"
        let @h=@h."\" middle click = same as '<tab>'\n"
    else
        let @h="\" ? : toggle help\n"
    endif

    put h

    let @h = old_h
endfunction
"FUNCTION: s:FindNodeLineNumber(path){{{2
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
    let pathcomponents = [substitute(t:currentRoot.path.GetPath(0), '/ *$', '', '')]
    "the index of the component we are searching for 
    let curPathComponent = 1

    let fullpath = a:treenode.path.GetPath(0)


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
"FUNCTION: s:FindRootNodeLineNumber(path){{{2
"Finds the line number of the root node  
function s:FindRootNodeLineNumber() 
    let rootLine = 1
    while getline(rootLine) !~ '^/'
        let rootLine = rootLine + 1
    endwhile
    return rootLine
endfunction

"FUNCTION: s:GetParentLineNum(ln) {{{2 
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
"FUNCTION: s:GetPath(ln) {{{2 
"Gets the full path to the node that is rendered on the given line number
"
"Args:
"ln: the line number to get the path for
function! s:GetPath(ln) 
    let line = getline(a:ln)

    "check to see if we have the root node 
    if line =~ '^\/'
        return t:currentRoot.path
    endif

    " in case called from outside the tree
    if line =~ '^[ ]*[^|`]' || line =~ '^$'
        return {}
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
                let sd = substitute (curLine, '^' . s:tree_markup_reg . '*',"","") 
                let sd = substitute (sd, ' -> .*', '',"") 

                " remove leading escape
                let sd = substitute (sd,'^\\', "", "")

                let dir = sd . dir
                continue
            endif
        endif
    endwhile
    let curFile = dir . curFile
    return s:oPath.New(curFile)
endfunction 
"FUNCTION: s:GetSelectedNode() {{{2 
"gets the treenode that the cursor is currently over
function! s:GetSelectedNode() 
    let path = s:GetPath(line("."))
    try 
        return t:currentRoot.FindNodeByAbsPath(path)
    catch
        return {}
    endtry
endfunction

"FUNCTION: s:GetTreeWinNum()"{{{2
"gets the nerd tree window number for this tab
function! s:GetTreeWinNum() 
    if exists("t:NERDTreeWinName")
        return bufwinnr(t:NERDTreeWinName)
    else
        return -1
    endif
endfunction
"FUNCTION: s:InitNerdTree(dir) {{{2 
"Initialized the NERD tree, where the root will be initialized with the given
"directory
"
"Arg:
"dir: the dir to init the root with
function s:InitNerdTree(dir)
    let dir = a:dir == '' ? expand("%:p:h") : a:dir

    if dir != ""
        try
            execute "lcd " . escape (dir, s:escape_chars)

            "this will ensure we always have an abs path (needed for the
            "oTreeNode class) 
            let dir = expand("%:p:h")
        catch
            echo "NERD_Tree: Error changing to directory: " . dir
            return
        endtry
    endif

    let t:treeShowHelp = 0
    let t:enableNERDTreeIgnore = 1


    let path = s:oPath.New(dir)
    let t:currentRoot = s:oTreeNode.New(path, {})
    call t:currentRoot.Open()

    if exists("t:NERDTreeWinSize")
        unlet t:NERDTreeWinSize
    endif
    call s:CreateTreeWin()

    call s:RenderTree()
endfunction

" Function: s:InstallDocumentation(full_name, revision)   {{{2
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
    :%s/{{{[1-9]/    /

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
"FUNCTION: s:OpenDirNodeSplit(treenode)"{{{2
"Open the file represented by the given node in a new window.
"No action is taken for file nodes
"
"ARGS:
"treenode: file node to open
function! s:OpenDirNodeSplit(treenode) 
    if a:treenode.path.isDirectory == 1
        call s:OpenNodeSplit(a:treenode)
    endif
endfunction
"FUNCTION: s:OpenFileNodeSplit(treenode)"{{{2
"Open the file represented by the given node in a new window.
"No action is taken for dir nodes
"
"ARGS:
"treenode: file node to open
function! s:OpenFileNodeSplit(treenode) 
    if a:treenode.path.isDirectory == 0
        call s:OpenNodeSplit(a:treenode)
    endif
endfunction
"FUNCTION: s:OpenNodeSplit(treenode)"{{{2
"Open the file/dir represented by the given node in a new window
"
"ARGS:
"treenode: file node to open
function! s:OpenNodeSplit(treenode) 
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
    exec("silent " . splitMode." sp " . a:treenode.path.GetPath(1))

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
"FUNCTION: s:PutCursorOnNode(treenode){{{2
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

"FUNCTION: s:RenderTree {{{2 
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
    call setline(line(".")+1, t:currentRoot.path.GetPath(0))
    normal j
    call s:DrawTree(t:currentRoot, 0, 0, [], len(t:currentRoot.children) == 1)

    "restore the view 
    call cursor(topLine, 1)
    normal zt
    call cursor(curLine, curCol)

    setlocal nomodifiable

endfunction
"FUNCTION: s:RestoreScreenState() {{{2 
"
"Sets the screen state back to what it was when s:SaveScreenState was last
"called.
"
"Assumes the cursor is in the NERDTree window
function s:RestoreScreenState()
    if !exists("t:NERDTreeOldTopLine") || !exists("t:NERDTreeOldPos")
        echoerr 'cannot restore screen'
        return
    endif

    call cursor(t:NERDTreeOldTopLine, 0)
    normal zt
    call setpos(".", t:NERDTreeOldPos)
endfunction
"FUNCTION: s:SaveScreenState() {{{2 
"Saves the current cursor position in the current buffer and the window
"scroll position 
"
"Assumes the cursor is in the NERDTree window
function s:SaveScreenState()
    let t:NERDTreeOldPos = getpos(".")
    normal H
    let t:NERDTreeOldTopLine = line(".")
    normal ``
endfunction
"FUNCTION: s:StripMarkupFromLine(line){{{2
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
"FUNCTION: s:Toggle(dir) {{{2 
"Toggles the NERD tree. I.e the NERD tree is open, it is closed, if it is
"closed it is restored or initialized (if it doesnt exist)     
"
"Args:
"dir: the full path for the root node (is only used if the NERD tree is being
"initialized.
function s:Toggle(dir)
    if exists("t:currentRoot")
        if s:GetTreeWinNum() == -1
            execute "lcd " . t:currentRoot.path.GetPath(1)
            call s:CreateTreeWin()
            call s:RenderTree()

            call s:RestoreScreenState()
        else
            call s:CloseTree()
        endif
    else
        call s:InitNerdTree(a:dir)
    endif
endfunction
"FUNCTION: s:WinToUnixPath(path){{{2
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
"FUNCTION: s:ActivateNode() {{{2
"If the current node is a file, open it in the previous window (or a new one
"if the previous is modified). If it is a directory then it is opened.
function s:ActivateNode()
    let treenode = s:GetSelectedNode()
    if treenode == {} 
        echo "NERD_tree: cannot open selected entry"
        return
    endif

    if treenode.path.isDirectory
        call treenode.ToggleOpen()
        call s:RenderTree()
        call s:PutCursorOnNode(treenode)
    else
        let oldwin = winnr()
        wincmd p
        if oldwin == winnr() || (&modified && s:BufInWindows(winbufnr(winnr())) < 2)
            wincmd p
            call s:OpenFileNodeSplit(treenode)
        else
            exec ("edit " . treenode.path.GetPath(1))
        endif
    endif
endfunction
"FUNCTION: s:BindMappings() {{{2
function s:BindMappings()
    " set up mappings and commands for this buffer
    nnoremap <buffer> <cr> :call <SID>ActivateNode()<cr>
    nnoremap <buffer> o :call <SID>ActivateNode()<cr>
    nnoremap <buffer> <tab> :call <SID>OpenEntrySplit()<cr>
    nnoremap <buffer> <2-leftmouse> :call <SID>ActivateNode()<cr>
    nnoremap <buffer> <middlerelease> :call <SID>OpenEntrySplit()<cr>
    nnoremap <buffer> <leftrelease> :call <SID>CheckForActivate()<cr>

    nnoremap <buffer> U :call <SID>UpDir(1)<cr>
    nnoremap <buffer> u :call <SID>UpDir(0)<cr>
    nnoremap <buffer> C :call <SID>ChRoot()<cr>

    nnoremap <buffer> R :call <SID>RefreshRoot()<cr>
    nnoremap <buffer> r :call <SID>RefreshCurrent()<cr>

    nnoremap <buffer> ? :call <SID>DisplayHelp()<cr>
    nnoremap <buffer> D :call <SID>ToggleShowHidden()<cr>
    nnoremap <buffer> f :call <SID>ToggleIgnoreFilter()<cr>
    nnoremap <buffer> x :call <SID>CloseCurrentDir()<cr>

    nnoremap <buffer> p :call <SID>JumpToParent()<cr>
    nnoremap <buffer> s :call <SID>JumpToSibling(1)<cr>
    nnoremap <buffer> S :call <SID>JumpToSibling(0)<cr>

    nnoremap <buffer> t :call <SID>OpenEntryNewTab(0)<cr>
    nnoremap <buffer> T :call <SID>OpenEntryNewTab(1)<cr>
endfunction
"FUNCTION: s:CheckForActivate() {{{2
"Checks if the click should open the current node, if so then activate() is
"called (directories are automatically opened if the symbol beside them is
"clicked)
function s:CheckForActivate()
    let startToCur = strpart(getline(line(".")), 0, col("."))
    
    let reg = '^' . s:tree_markup_reg .'*[' . s:tree_dir_open . s:tree_dir_closed . ']$'
    if startToCur =~ reg
        call s:ActivateNode()
    endif
endfunction
" FUNCTION: s:ChRoot() {{{2
" changes the current root to the selected one
function s:ChRoot() 
    let treenode = s:GetSelectedNode()
    if treenode == {} 
        echo "NERD_tree: cannot change root node"
        return
    elseif treenode.path.isDirectory == 0
        echo "NERD_tree: cannot change root node"
        return
    endif

    if treenode.isOpen == 0
        call treenode.Open()
    endif

    execute "lcd " treenode.path.GetPath(1)

    let t:currentRoot = treenode
    call s:RenderTree()
endfunction
" FUNCTION: s:CloseCurrentDir() {{{2
" closes the parent dir of the current node
function s:CloseCurrentDir() 
    let treenode = s:GetSelectedNode()
    let parent = treenode.parent
    if parent.path.GetPath(0) == t:currentRoot.path.GetPath(0)
        echo "NERDTree: cannot close tree root"
    else
        let linenum = s:GetParentLineNum(line("."))
        call treenode.parent.Close()
        call s:RenderTree()
        call cursor(linenum, col("."))
    endif
endfunction
" FUNCTION: s:DisplayHelp() {{{2
" toggles the help display
function s:DisplayHelp() 
    let t:treeShowHelp = t:treeShowHelp ? 0 : 1
    call s:RenderTree()
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
" FUNCTION: s:OpenEntryNewTab(stayCurrentTab) {{{2
" Opens the currently selected file from the explorer in a
" new tab
"
" Args:
" stayCurrentTab: if 1 then vim will stay in the current tab, if 0 then vim
" will go to the tab where the new file is opened
function! s:OpenEntryNewTab(stayCurrentTab) 
    let treenode = s:GetSelectedNode()
    if treenode != {}
        let curTabNr = tabpagenr()
        exec "tabedit " . treenode.path.GetPath(1)
        if a:stayCurrentTab
            exec "tabnext " . curTabNr
        endif
    else
        echo "NERD_tree: cannot open selected entry"
    endif
endfunction 
" FUNCTION: s:OpenEntrySplit() {{{2
" Opens the currently selected file from the explorer in a
" new window 
function! s:OpenEntrySplit() 
    let treenode = s:GetSelectedNode()
    if treenode != {}
        call s:OpenFileNodeSplit(treenode)
    else
        echo "NERD_tree: cannot open selected entry"
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

    let curDir = treenode.path.GetDir() . '/'
    let parentNode = t:currentRoot.FindNodeByAbsPath( s:oPath.New(curDir) )
    if parentNode == {}
        echo "NERD_tree: cannot refresh selected dir"
        return
    endif

    call parentNode.Refresh()
    call s:RenderTree()
endfunction
" FUNCTION: s:ToggleIgnoreFilter() {{{2
" toggles the use of the NERDTreeIgnore option 
function s:ToggleIgnoreFilter() 
    let t:enableNERDTreeIgnore = !t:enableNERDTreeIgnore
    call t:currentRoot.Refresh()
    call s:RenderTree()
endfunction
" FUNCTION: s:ToggleShowHidden() {{{2
" toggles the display of hidden files
function s:ToggleShowHidden() 
    let g:NERDTreeShowHidden = !g:NERDTreeShowHidden
    call t:currentRoot.Refresh()
    call s:RenderTree()
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
            let path = s:oPath.New(getcwd())
            let newRoot = s:oTreeNode.New(path, {})
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
" Section: Doc installation call {{{1
silent call s:InstallDocumentation(expand('<sfile>:p'), s:NERD_tree_version)
"============================================================
finish
" Section: The help file {{{1 
"=============================================================================
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
                                                                   *NERD_tree*
1. Intro {{{2 ~

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
                                                     *NERD_tree-functionality*
2. Functionality provided {{{2 ~

------------------------------------------------------------------------------
                                                          *NERD_tree-commands*
2.1. Commands {{{3 ~

:NERDTree [start-directory]                                 *:NERDTree*
                Opens a fresh NERD tree in [start-directory] or the current
                directory if [start-directory] isnt specified.
                For example: >
                    :NERDTree /home/marty/vim7/src
<               will open a NERD tree in /home/marty/vim7/src.

:NERDTreeToggle [start-directory]                           *:NERDTreeToggle*
                If a NERD tree already exists for this tab, it is reopened and
                rendered again.  If no NERD tree exists for this tab then this
                command acts the same as the |:NERDTree| command.



------------------------------------------------------------------------------
                                                          *NERD_tree-mappings*
2.2. NERD tree Mappings {{{3 ~

When the cursor is in the NERD tree window the following mappings may be used:

Key         Description~

o           If the cursor is on a file, this file is opened in the previous
            window. If the cursor is on a directory, the directory node is
            expanded in the tree.

<ret>       See 'o'

<tab>       Only applies to files. Opens the selected file in a new split
            window. 

t           Only applies to files. Opens the selected file in a new tab. 

T           Only applies to files. Opens the selected file in a new tab, but
            keeps the focus in the current tab.

x           Closes the directory that the cursor is inside.

C           Only applies to directories. Changes the current root of the NERD
            tree to the selected directory.

u           Change the root of the tree up one directory.

U           Same as 'u' except the old root is left open.

r           Refreshes the directory that the cursor is currently inside. If
            the cursor is on a directory node, this directory is refreshed.

R           Refreshes the current root of the tree.

p           Moves the cursor to parent directory of the directory it is
            currently inside.

s           Moves the cursor to next sibling of the current node.

S           Moves the cursor to previous sibling of the current node.

D           Toggles whether hidden files are shown or not.

f           Toggles whether the file filter (as specified in the
            |NERDTreeIgnore| option) is used.

?           Toggles the display of the quick help at the top of the tree.

The following mouse mappings are available:

Key             Description~

double click    Has the same effect as pressing 'o'

middle click    Has the same effect as pressing '<tab>'


Additionally, directories can be opened and closed by clicking the '+' and '~'
symbols on their left.
==============================================================================
                                                     *NERD_tree-customisation*
3. Customisation {{{2 ~


------------------------------------------------------------------------------
                                                      *NERD_tree-cust-summary*
3.1. Customisation summary {{{3 ~

The script provides the following options that can customise the behaviour the
NERD tree. These options should be set in your vimrc.

|loaded_nerd_tree|              Turns off the script

|NERDTreeIgnore|                Tells the NERD tree which files to ignore.

|NERDTreeSortDirs|              Tells the NERD tree how to position the
                                directory/file nodes within their parent node. 

|NERDTreeShowHidden|            Tells the NERD tree whether to display hidden
                                files on startup

|NERDTreeWinSize|               Sets the window size when the NERD tree is
                                opened

------------------------------------------------------------------------------
                                                      *NERD_tree-cust-details*
3.2. Customisation details {{{3 ~

To enable any of the below options you should put the given line in your 
~/.vimrc

                                                            *loaded_nerd_tree*              
If this plugin is making you feel homicidal, it may be a good idea to turn it
off with this line in your vimrc: >
    let loaded_nerd_tree=1
<

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
                                                            *NERDTreeSortDirs*
This option is used to tell the NERD tree how to position file nodes and
directory nodes within their parent. This option can take 3 values: >
    let NERDTreeSortDirs=0
    let NERDTreeSortDirs=1
    let NERDTreeSortDirs=-1
<
If NERDTreeSortDirs is set to 0 then no distinction is made between file nodes
and directory nodes and they are sorted as they appear in a directory listing
on the operating system (usually alphbetically).
If NERDTreeSortDirs is set to 1 then directories will appear above the files. 
If NERDTreeSortDirs is set to -1 then directories will appear below the files. 

This option defaults to 0.

------------------------------------------------------------------------------
                                                          *NERDTreeShowHidden*            
This option tells vim whether to display hidden files by default. This option
can be dynamically toggled with the D mapping see |NERD_tree_mappings|.
Use the follow line to change this option: >
    let NERDTreeShowHidden=X
<
                                                       
This option defaults to 0.

------------------------------------------------------------------------------
                                                             *NERDTreeWinSize*               
This option is used to change the size of the NERD tree when it is loaded.
To use this option, stick the following line in your vimrc: >
    let NERDTreeWinSize=[New Win Size]
<

This option defaults to 30.

==============================================================================
                                                              *NERD_tree-todo*
4. TODO list {{{2 ~

Window manager integration?

More mappings to make it faster to use.

make it be able to edit the filesystem (create/delete directories and files)?

make it highlight read only files, symlinks etc.

make the position of the nerd tree customisable

make the mappings customisable?

dynamic hiding of tree content (eg, if you dont want to see a particular
directory for the rest of the current vim session, you can hide it with a
mapping)

make a "window exporer" mode where only directories are shown

==============================================================================
                                                            *NERD_tree-author*
5. The Author {{{2 ~

The author of the NERD tree is a terrible terrible monster called Martyzilla
who gobbles up small children with milk and sugar for breakfast. He has an
odd love/hate relationship with computers (but monsters hate everything by
nature you know...) which can be awkward for him since he is a professional
computer nerd for a living.

He can be reached at martin_grenfell at msn.com. He would love to hear from
you, so feel free to send him suggestions and/or comments about this plugin.
Dont be shy --- the worst he can do is slaughter you and stuff you in the
fridge for later.    

==============================================================================
                                                           *NERD_tree-credits*
6. Credits {{{2 ~

Thanks to Tim Carey-Smith for testing/using the NERD tree from the first
pre-beta version, and for his many suggestions.

Thanks to Vigil for trying it out before the first release :) and suggesting
that mappings to open files in new tabs should be implemented.

Thanks to Nick Brettell for testing, fixing my spelling and suggesting i put a
    .. (up a directory)
line in the gui.


=== END_DOC
" vim: set ts=4 sw=4 foldmethod=marker foldmarker={{{,}}} foldlevel=2 fdc=4:
