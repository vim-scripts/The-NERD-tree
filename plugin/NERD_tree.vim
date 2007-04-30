" vim global plugin that provides a nice tree explorer
" Last Change:  28 april 2007
" Maintainer:   Martin Grenfell <martin_grenfell at msn dot com>
let s:NERD_tree_version = '2.2.2'

"A help file is installed when the script is run for the first time. 
"Go :help NERD_tree.txt to see it.

" SECTION: Script init stuff {{{1
"============================================================
if exists("loaded_nerd_tree")
    finish
endif
if v:version < 700
    echoerr "NERDTree: this plugin requires vim >= 7. DOWNLOAD IT! You'll thank me later!"
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
function! s:InitVariable(var, value)
    if !exists(a:var)
        exec 'let ' . a:var . ' = ' . "'" . a:value . "'"
        return 1
    endif
    return 0
endfunction

"SECTION: Init variable calls {{{2 
call s:InitVariable("g:NERDChristmasTree", 1)
call s:InitVariable("g:NERDTreeChDirMode", 1)
if !exists("g:NERDTreeIgnore")
    let g:NERDTreeIgnore = ['\~$']
endif
call s:InitVariable("g:NERDTreeHighlightCursorline", 1)
call s:InitVariable("g:NERDTreeMouseMode", 1)
call s:InitVariable("g:NERDTreeShowHidden", 0)
call s:InitVariable("g:NERDTreeShowFiles", 1)
call s:InitVariable("g:NERDTreeSortDirs", 1)

if !exists("g:NERDTreeSortOrder")
    let g:NERDTreeSortOrder = ['\/$', '*', '\.swp$',  '\.bak$', '\~$']
else
    "if there isnt a * in the sort sequence then add one 
    if count(g:NERDTreeSortOrder, '*') < 1
        call add(g:NERDTreeSortOrder, '*')
    endif
endif

"we need to use this number many times for sorting... so we calculate it only
"once here 
let g:NERDTreeSortStarIndex = index(g:NERDTreeSortOrder, '*')

call s:InitVariable("g:NERDTreeSplitVertical", 1)
call s:InitVariable("g:NERDTreeWinPos", 1)
call s:InitVariable("g:NERDTreeWinSize", 31)

let s:running_windows = has("win16") || has("win32") || has("win64")

"init the shell command that will be used to remove dir trees 
"
"Note: the space after the command is important
if s:running_windows
    call s:InitVariable("g:NERDTreeRemoveDirCmd", 'rmdir /s /q ')
else
    call s:InitVariable("g:NERDTreeRemoveDirCmd", 'rm -rf ')
endif

"SECTION: Init variable calls for key mappings {{{2 
call s:InitVariable("g:NERDTreeMapActivateNode", "o")
call s:InitVariable("g:NERDTreeMapChangeRoot", "C")
call s:InitVariable("g:NERDTreeMapChdir", "cd")
call s:InitVariable("g:NERDTreeMapCloseChildren", "X")
call s:InitVariable("g:NERDTreeMapCloseDir", "x")
call s:InitVariable("g:NERDTreeMapExecute", "!")
call s:InitVariable("g:NERDTreeMapFilesystemMenu", "m")
call s:InitVariable("g:NERDTreeMapHelp", "?")
call s:InitVariable("g:NERDTreeMapJumpNextSibling", "s")
call s:InitVariable("g:NERDTreeMapJumpParent", "p")
call s:InitVariable("g:NERDTreeMapJumpPrevSibling", "S")
call s:InitVariable("g:NERDTreeMapOpenExpl", "e")
call s:InitVariable("g:NERDTreeMapOpenExplNewWin", "E")
call s:InitVariable("g:NERDTreeMapOpenInTab", "t")
call s:InitVariable("g:NERDTreeMapOpenInTabSilent", "T")
call s:InitVariable("g:NERDTreeMapOpenRecursively", "O")
call s:InitVariable("g:NERDTreeMapOpenSplit", "<tab>")
call s:InitVariable("g:NERDTreeMapQuit", "q")
call s:InitVariable("g:NERDTreeMapRefresh", "r")
call s:InitVariable("g:NERDTreeMapRefreshRoot", "R")
call s:InitVariable("g:NERDTreeMapToggleFiles", "F")
call s:InitVariable("g:NERDTreeMapToggleFilters", "f")
call s:InitVariable("g:NERDTreeMapToggleHidden", "H")
call s:InitVariable("g:NERDTreeMapUpdir", "u")
call s:InitVariable("g:NERDTreeMapUpdirKeepOpen", "U")


"SECTION: Script level variable declaration{{{2
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
let s:tree_up_dir_line = '.. (up a dir)'
let s:tree_RO_str = ' [RO]'
let s:tree_RO_str_reg = ' \[RO\]'

let s:os_slash = '/'
if s:running_windows
    let s:os_slash = '\'
endif


" SECTION: Commands {{{1
"============================================================
"init the command that users start the nerd tree with 
command! -n=? -complete=dir NERDTree :call s:InitNerdTree('<args>')
command! -n=? -complete=dir NERDTreeToggle :call s:Toggle('<args>')
" SECTION: Auto commands {{{1
"============================================================
"Save the cursor position whenever we close the nerd tree
exec "autocmd BufWinLeave *". s:NERDTreeWinName ."* :call <SID>SaveScreenState()"

"SECTION: Classes {{{1
"============================================================
"CLASS: oTreeFileNode {{{2
"This class is the parent of the oTreeDirNode class and constitures the
"'Component' part of the composite design pattern between the treenode
"classes.
"============================================================
let s:oTreeFileNode = {}
"FUNCTION: oTreeFileNode.CompareNodes {{{3 
"This is supposed to be a class level method but i cant figure out how to
"get func refs to work from a dict.. 
"
"A class level method that compares two nodes
"
"Args:
"n1, n2: the 2 nodes to compare
function! s:CompareNodes(n1, n2)
    return a:n1.path.CompareTo(a:n2.path)
endfunction

"FUNCTION: oTreeFileNode.Delete {{{3 
"Removes this node from the tree and calls the Delete method for its path obj
function! s:oTreeFileNode.Delete() dict
    call self.path.Delete()
    call self.parent.RemoveChild(self)
endfunction

"FUNCTION: oTreeFileNode.Equals(treenode) {{{3 
"
"Compares this treenode to the input treenode and returns 1 if they are the
"same node.
"
"Use this method instead of ==  because sometimes when the treenodes contain
"many children, vim seg faults when doing ==
"
"Args:
"treenode: the other treenode to compare to
function! s:oTreeFileNode.Equals(treenode) dict
    return self.path.Str(1) == a:treenode.path.Str(1)
endfunction

"FUNCTION: oTreeFileNode.FindNode(path) {{{3 
"Returns self if this node.path.Equals the given path.
"Returns {} if not equal.
"
"Args:
"path: the path object to compare against
function! s:oTreeFileNode.FindNode(path) dict
    if a:path.Equals(self.path)
        return self
    endif
    return {}
endfunction
"FUNCTION: oTreeFileNode.FindSibling(direction) {{{3 
"
"Finds the next sibling for this node in the indicated direction  
"
"Args:
"direction: 0 if you want to find the previous sibling, 1 for the next sibling
"
"Return:
"a treenode object or {} if no sibling could be found
function! s:oTreeFileNode.FindSibling(direction) dict
    "if we have no parent then we can have no siblings 
    if self.parent != {}

        "get the index of this node in its parents children 
        let siblingIndx = self.parent.GetChildIndex(self.path)

        if siblingIndx != -1
            "move a long to the next potential sibling node 
            let siblingIndx = a:direction == 1 ? siblingIndx+1 : siblingIndx-1

            "keep moving along to the next sibling till we find one that is valid 
            let numSiblings = len(self.parent.children)
            while siblingIndx >= 0 && siblingIndx < numSiblings

                "if the next node is not an ignored node (i.e. wont show up in the
                "view) then return it
                if self.parent.children[siblingIndx].path.Ignore() == 0
                    return self.parent.children[siblingIndx]
                endif

                "go to next node 
                let siblingIndx = a:direction == 1 ? siblingIndx+1 : siblingIndx-1
            endwhile
        endif
    endif

    return {}
endfunction


"FUNCTION: oTreeFileNode.New(path) {{{3 
"Returns a new TreeNode object with the given path and parent
"
"Args:
"path: a path object representing the full filesystem path to the file/dir that the node represents
function! s:oTreeFileNode.New(path) dict
    if a:path.isDirectory
        return s:oTreeDirNode.New(a:path)
    else
        let newTreeNode = {}
        let newTreeNode = copy(self)
        let newTreeNode.path = a:path
        let newTreeNode.parent = {}
        return newTreeNode
    endif
endfunction

"FUNCTION: oTreeFileNode.Rename {{{3 
"Calls the rename method for this nodes path obj 
function! s:oTreeFileNode.Rename(newName) dict
    call self.path.Rename(a:newName)
    call self.parent.RemoveChild(self)

    let parentPath = self.path.GetPathTrunk()
    let newParent = t:NERDTreeRoot.FindNode(parentPath)

    if newParent != {}
        call newParent.CreateChild(self.path, 1)
    endif
endfunction

"FUNCTION: oTreeFileNode.StrDisplay() {{{3 
"
"Returns a string that specifies how the node should be represented as a
"string
"
"Return:
"a string that can be used in the view to represent this node
function! s:oTreeFileNode.StrDisplay() dict
    return self.path.StrDisplay()
endfunction

"CLASS: oTreeDirNode {{{2
"This class is a child of the oTreeFileNode class and constitutes the
"'Composite' part of the composite design pattern between the treenode
"classes.
"============================================================
let s:oTreeDirNode = copy(s:oTreeFileNode)
"FUNCTION: oTreeDirNode.AddChild(treenode, inOrder) {{{3 
"Adds the given treenode to the list of children for this node
"
"Args:
"-treenode: the node to add
"-inOrder: 1 if the new node should be inserted in sorted order
function! s:oTreeDirNode.AddChild(treenode, inOrder) dict
    call add(self.children, a:treenode)
    let a:treenode.parent = self

    if a:inOrder
        call self.SortChildren()
    endif
endfunction

"FUNCTION: oTreeDirNode.Close {{{3 
"Closes this directory
function! s:oTreeDirNode.Close() dict
    let self.isOpen = 0
endfunction

"FUNCTION: oTreeDirNode.CloseChildren {{{3 
"Closes all the child dir nodes of this node 
function! s:oTreeDirNode.CloseChildren() dict
    for i in self.children
        if i.path.isDirectory
            call i.Close()
            call i.CloseChildren()
        endif
    endfor
endfunction

"FUNCTION: oTreeDirNode.CreateChild(path, inOrder) {{{3 
"Instantiates a new child node for this node with the given path. The new
"nodes parent is set to this node.
"
"Args:
"path: a Path object that this node will represent/contain
"inOrder: 1 if the new node should be inserted in sorted order
"
"Returns:
"the newly created node
function! s:oTreeDirNode.CreateChild(path, inOrder) dict
    let newTreeNode = s:oTreeFileNode.New(a:path)
    call self.AddChild(newTreeNode, a:inOrder)
    return newTreeNode
endfunction

"FUNCTION: oTreeDirNode.FindNode(path) {{{3 
"Will find one of the children (recursively) that has the given path
"
"Args:
"path: a path object
unlet s:oTreeDirNode.FindNode
function! s:oTreeDirNode.FindNode(path) dict
    if a:path.Equals(self.path)
        return self
    endif
    if stridx(a:path.Str(1), self.path.Str(1), 0) == -1
        return {}
    endif

    if self.path.isDirectory
        for i in self.children
            let retVal = i.FindNode(a:path)
            if retVal != {}
                return retVal
            endif
        endfor
    endif
    return {}
endfunction

"FUNCTION: oTreeDirNode.GetChildDirs() {{{3 
"Returns an array of all children of this node that are directories
"
"Return:
"an array of directory treenodes
function! s:oTreeDirNode.GetChildDirs() dict
    let toReturn = []
    for i in self.children
        if i.path.isDirectory
            call add(toReturn, i)
        endif
    endfor
    return toReturn
endfunction

"FUNCTION: oTreeDirNode.GetChildFiles() {{{3 
"Returns an array of all children of this node that are files
"
"Return:
"an array of file treenodes
function! s:oTreeDirNode.GetChildFiles() dict
    let toReturn = []
    for i in self.children
        if i.path.isDirectory == 0
            call add(toReturn, i)
        endif
    endfor
    return toReturn
endfunction

"FUNCTION: oTreeDirNode.GetChildrenToDisplay() {{{3 
"Returns a list of children to display for this node, in the correct order
"
"Return:
"an array of treenodes
function! s:oTreeDirNode.GetChildrenToDisplay() dict
    let toReturn = []
    for i in self.children
        if i.path.Ignore() == 0
            call add(toReturn, i)
        endif
    endfor
    return toReturn
endfunction

"FUNCTION: oTreeDirNode.GetChild(path) {{{3 
"Returns child node of this node that has the given path or {} if no such node
"exists.
"
"This function doesnt not recurse into child dir nodes
"
"Args:
"path: a path object
function! s:oTreeDirNode.GetChild(path) dict
    if stridx(a:path.Str(1), self.path.Str(1), 0) == -1
        return {}
    endif

    let index = self.GetChildIndex(a:path)
    if index == -1
        return {}
    else
        return self.children[index]
    endif

endfunction

"FUNCTION: oTreeDirNode.GetChildIndex(path) {{{3 
"Returns the index of the child node of this node that has the given path or
"-1 if no such node exists.
"
"This function doesnt not recurse into child dir nodes
"
"Args:
"path: a path object
function! s:oTreeDirNode.GetChildIndex(path) dict
    if stridx(a:path.Str(1), self.path.Str(1), 0) == -1
        return -1
    endif

    "do a binary search for the child 
    let a = 0
    let z = len(self.children)
    while a < z
        let mid = (a+z)/2
        let diff = a:path.CompareTo(self.children[mid].path)

        if diff == -1
            let z = mid
        elseif diff == 1
            let a = mid+1
        else
            return mid
        endif
    endwhile
    return -1
endfunction

"FUNCTION: oTreeDirNode.InitChildren {{{3 
"Removes all childen from this node and re-reads them
"
"Return: the number of child nodes read
function! s:oTreeDirNode.InitChildren() dict
    "remove all the current child nodes 
    let self.children = []

    "get an array of all the files in the nodes dir 
    let filesStr = globpath(self.path.GetDir(0), '*') . "\n" . globpath(self.path.GetDir(0), '.*')
    let files = split(filesStr, "\n")

    let invalidFilesFound = 0
    for i in files

        "filter out the .. and . directories 
        if i !~ '\.\.$' && i !~ '\.$'

            "put the next file in a new node and attach it 
            try
                let path = s:oPath.New(i)
                call self.CreateChild(path, 0)
            catch /^NERDTree.Path.InvalidArguments/
                let invalidFilesFound = 1
            endtry
        endif
    endfor

    call self.SortChildren()

    if invalidFilesFound
        call s:EchoWarning("Warning: some files could not be loaded into the NERD tree")
    endif
    return len(self.children)
endfunction
"FUNCTION: oTreeDirNode.New(path) {{{3 
"Returns a new TreeNode object with the given path and parent
"
"Args:
"path: a path object representing the full filesystem path to the file/dir that the node represents
unlet s:oTreeDirNode.New
function! s:oTreeDirNode.New(path) dict
    if a:path.isDirectory != 1
        throw "NERDTree.TreeDirNode.InvalidArguments exception. A TreeDirNode object must be instantiated with a directory Path object."
    endif

    let newTreeNode = copy(self)
    let newTreeNode.path = a:path

    let newTreeNode.isOpen = 0
    let newTreeNode.children = []

    let newTreeNode.parent = {}

    return newTreeNode
endfunction
"FUNCTION: oTreeDirNode.Open {{{3 
"Reads in all this nodes children
"
"Return: the number of child nodes read
function! s:oTreeDirNode.Open() dict
    let self.isOpen = 1
    if self.children == []
        return self.InitChildren()
    else
        return 0
    endif
endfunction

"FUNCTION: oTreeDirNode.OpenRecursively {{{3 
"Opens this treenode and all of its children whose paths arent 'ignored'
"because of the file filters.
"
"This method is actually a wrapper for the OpenRecursively2 method which does
"the work.
function! s:oTreeDirNode.OpenRecursively() dict
    call self.OpenRecursively2(1)
endfunction

"FUNCTION: oTreeDirNode.OpenRecursively2 {{{3 
"Dont call this method from outside this object.
"
"Opens this all children of this treenode recursively if either:
"   *they arent filtered by file filters
"   *a:forceOpen is 1
"
"Args:
"forceOpen: 1 if this node should be opened regardless of file filters
function! s:oTreeDirNode.OpenRecursively2(forceOpen) dict
    if self.path.Ignore() == 0 || a:forceOpen
        let self.isOpen = 1
        if self.children == []
            call self.InitChildren()
        endif

        for i in self.children
            if i.path.isDirectory == 1
                call i.OpenRecursively2(0) 
            endif
        endfor
    endif
endfunction

"FUNCTION: oTreeDirNode.Refresh {{{3 
function! s:oTreeDirNode.Refresh() dict
    let newChildNodes = []
    let invalidFilesFound = 0

    "go thru all the files/dirs under this node 
    let filesStr = globpath(self.path.GetDir(0), '*') . "\n" . globpath(self.path.GetDir(0), '.*')
    let files = split(filesStr, "\n")
    for i in files
        if i !~ '\.\.$' && i !~ '\.$'

            try
                "create a new path and see if it exists in this nodes children 
                let path = s:oPath.New(i)
                let newNode = self.GetChild(path)
                if newNode != {} 

                    "if the existing node is a dir can be refreshed then
                    "refresh it   
                    if newNode.path.isDirectory && (!empty(newNode.children) || newNode.isOpen == 1)
                        call newNode.Refresh()

                    "if we have a filenode then refresh the path 
                    elseif newNode.path.isDirectory == 0
                        call newNode.path.Refresh()
                    endif

                    call add(newChildNodes, newNode)

                "the node doesnt exist so create it 
                else
                    let newNode = s:oTreeFileNode.New(path)
                    let newNode.parent = self
                    call add(newChildNodes, newNode)
                endif


            catch /^NERDTree.InvalidArguments/
                let invalidFilesFound = 1
            endtry
        endif
    endfor

    "swap this nodes children out for the children we just read/refreshed 
    let self.children = newChildNodes
    call self.SortChildren()
    
    if invalidFilesFound
        call s:EchoWarning("Warning: some files could not be loaded into the NERD tree")
    endif
endfunction

"FUNCTION: oTreeDirNode.RemoveChild {{{3 
"
"Removes the given treenode from this nodes set of children
"
"Args:
"treenode: the node to remove
"
"Throws a NERDTree.TreeDirNode exception if the given treenode is not found
function! s:oTreeDirNode.RemoveChild(treenode) dict
    for i in range(0, len(self.children)-1)
        if self.children[i].Equals(a:treenode)
            call remove(self.children, i)
            return
        endif
    endfor

    throw "NERDTree.TreeDirNode exception: child node was not found"
endfunction

"FUNCTION: oTreeDirNode.SortChildren {{{3 
"
"Sorts the children of this node according to alphabetical order and the
"directory priority.
"
function! s:oTreeDirNode.SortChildren() dict
    let CompareFunc = function("s:CompareNodes")
    call sort(self.children, CompareFunc)
endfunction

"FUNCTION: oTreeDirNode.ToggleOpen {{{3 
"Opens this directory if it is closed and vice versa
function! s:oTreeDirNode.ToggleOpen() dict
    if self.isOpen == 1
        call self.Close()
    else
        call self.Open()
    endif
endfunction

"FUNCTION: oTreeDirNode.TransplantChild(newNode) {{{3 
"Replaces the child of this with the given node (where the child node's full
"path matches a:newNode's fullpath). The search for the matching node is
"non-recursive
"
"Arg:
"newNode: the node to graft into the tree 
function! s:oTreeDirNode.TransplantChild(newNode) dict
    for i in range(0, len(self.children)-1)
        if self.children[i].Equals(a:newNode)
            let self.children[i] = a:newNode
            let a:newNode.parent = self
            break
        endif
    endfor
endfunction
"============================================================
"CLASS: oPath {{{2
"============================================================
let s:oPath = {} 
"FUNCTION: oPath.ChangeToDir() {{{3 
function! s:oPath.ChangeToDir() dict
    let dir = self.Str(1)
    if self.isDirectory == 0
        let dir = self.GetPathTrunk().Str(1)
    endif

    try
        execute "cd " . dir
        echo "NERDTree: CWD is now: " . getcwd()
    catch
        throw "NERDTree.Path.Change exception: cannot change to " . dir
    endtry
endfunction

"FUNCTION: oPath.ChopTrailingSlash(str) {{{3 
function! s:oPath.ChopTrailingSlash(str) dict
    if a:str =~ '\/$'
        return substitute(a:str, "\/$", "", "")
    else
        return substitute(a:str, "\\$", "", "")
    endif
endfunction

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
"Return:
"1, -1 or 0
function! s:oPath.CompareTo(path) dict
    let thisPath = self.GetLastPathComponent(1)
    let thatPath = a:path.GetLastPathComponent(1)

    "if the paths are the same then clearly we return 0 
    if thisPath == thatPath
        return 0
    endif

    let thisSS = self.GetSortOrderIndex()
    let thatSS = a:path.GetSortOrderIndex()
    
    "compare the sort sequences, if they are different then the return
    "value is easy 
    if thisSS < thatSS
        return -1
    elseif thisSS > thatSS 
        return 1
    else
        "if the sort sequences are teh same then compare the paths
        "alphabetically 
        if thisPath < thatPath
            return -1
        else
            return 1
        endif
    endif
endfunction

"FUNCTION: oPath.Create() {{{3 
"
"Factory method.
"
"Creates a path object with the given path. The path is also created on the
"filesystem. If the path already exists, a NERDTree.Path.Exists exception is
"thrown. If any other errors occur, a NERDTree.Path exception is thrown.
"
"Args:
"fullpath: the full filesystem path to the file/dir to create
function! s:oPath.Create(fullpath) dict
    "bail if the a:fullpath already exists 
    if isdirectory(a:fullpath) || filereadable(a:fullpath)
        throw "NERDTree.Path.Exists Exception: Directory Exists: '" . a:fullpath . "'"
    endif

    "get the unix version of the input path 
    let fullpath = a:fullpath
    if s:running_windows
        let fullpath = s:oPath.WinToUnixPath(fullpath)
    endif

    try 

        "if it ends with a slash, assume its a dir create it 
        if fullpath =~ '\/$'
            "whack the trailing slash off the end if it exists 
            let fullpath = substitute(fullpath, '\/$', '', '')

            call mkdir(fullpath, 'p')

        "assume its a file and create 
        else
            call writefile([], fullpath)
        endif
    catch /.*/
        throw "NERDTree.Path Exception: Could not create path: '" . a:fullpath . "'"
    endtry

    return s:oPath.New(fullpath)
endfunction

"FUNCTION: oPath.Delete() {{{3 
"
"Deletes the file represented by this path.
"Deletion of directories is not supported
"
"Throws NERDTree.Path.Deletion exceptions
function! s:oPath.Delete() dict
    if self.isDirectory 

        let cmd = ""
        if s:running_windows
            "if we are runnnig windows then put quotes around the pathstring 
            let cmd = g:NERDTreeRemoveDirCmd . self.StrForOS(1)
        else
            let cmd = g:NERDTreeRemoveDirCmd . self.StrForOS(0)
        endif
        let success = system(cmd)

        if v:shell_error != 0
            throw "NERDTree.Path.Deletion Exception: Could not delete directory: '" . self.StrForOS(0) . "'"
        endif
    else
        let success = delete(self.Str(0))
        if success != 0
            throw "NERDTree.Path.Deletion Exception: Could not delete file: '" . self.Str(0) . "'"
        endif
    endif
endfunction

"FUNCTION: oPath.GetDir() {{{3 
"
"Gets the directory part of this path. If this path IS a directory then the
"whole thing is returned
"
"Args:
"trailingSlash: 1 if a trailing slash is to be stuck on the end of the
"returned dir
"
"Return:
"string
function! s:oPath.GetDir(trailingSlash) dict
    let toReturn = ''
    if self.isDirectory
        let toReturn = '/'. join(self.pathSegments, '/')
    else
        let toReturn = '/'. join(self.pathSegments[0:-2], '/')
    endif

    if a:trailingSlash && toReturn !~ '\/$'
        let toReturn = toReturn . '/'
    endif

    return toReturn
endfunction

"FUNCTION: oPath.GetFile() {{{3 
"
"Returns the file component of this path. 
"
"Throws NERDTree.IllegalOperation exception if the node is a directory node 
function! s:oPath.GetFile() dict
    if self.isDirectory == 0
        return self.GetLastPathComponent(0)
    else
        throw "NERDTree.Path.IllegalOperation Exception: cannot get file component of a directory path"
    endif
endfunction

"FUNCTION: oPath.GetLastPathComponent(dirSlash) {{{3 
"
"Gets the last part of this path.   
"
"Args:
"dirSlash: if 1 then a trailing slash will be added to the returned value for
"directory nodes.
function! s:oPath.GetLastPathComponent(dirSlash) dict
    if empty(self.pathSegments)
        return ''
    endif
    let toReturn = self.pathSegments[-1]
    if a:dirSlash && self.isDirectory
        let toReturn = toReturn . '/'
    endif
    return toReturn
endfunction

"FUNCTION: oPath.GetPathTrunk() {{{3 
"Gets the path without the last segment on the end.
function! s:oPath.GetPathTrunk() dict
    return s:oPath.New('/' . join(self.pathSegments[0:-2], '/'))
endfunction

"FUNCTION: oPath.GetSortOrderIndex() {{{3 
"returns the index of the pattern in g:NERDTreeSortOrder that this path matches 
function! s:oPath.GetSortOrderIndex() dict
    let i = 0
    while i < len(g:NERDTreeSortOrder)
        if  self.GetLastPathComponent(1) =~ g:NERDTreeSortOrder[i]
            return i
        endif
        let i = i + 1
    endwhile
    return g:NERDTreeSortStarIndex
endfunction

"FUNCTION: oPath.Ignore() {{{3 
"returns true if this path should be ignored
function! s:oPath.Ignore() dict
    let lastPathComponent = self.GetLastPathComponent(0)

    "filter out the user specified paths to ignore 
    if t:NERDTreeIgnoreEnabled
        for i in g:NERDTreeIgnore
            if lastPathComponent =~ i
                return 1
            endif
        endfor
    endif

    "dont show hidden files unless instructed to 
    if g:NERDTreeShowHidden == 0 && lastPathComponent =~ '^\.'
        return 1
    endif

    if g:NERDTreeShowFiles == 0 && self.isDirectory == 0
        return 1
    endif

    return 0
endfunction

"FUNCTION: oPath.Equals() {{{3 
"
"Determines whether 2 path objecs are "equal".
"They are equal if the paths they represent are the same
"
"Args:
"path: the other path obj to compare this with
function! s:oPath.Equals(path) dict
    let this = self.ChopTrailingSlash(self.Str(1))
    let that = self.ChopTrailingSlash(a:path.Str(1))
    return this == that
endfunction

"FUNCTION: oPath.New() {{{3 
"
"The Constructor for the Path object
"Throws NERDTree.Path.InvalidArguments exception.
function! s:oPath.New(fullpath) dict
    let newPath = copy(self)

    call newPath.ReadInfoFromDisk(a:fullpath)

    return newPath
endfunction

"FUNCTION: oPath.NewMinimal() {{{3 
function! s:oPath.NewMinimal(fullpath) dict
    let newPath = copy(self)

    let fullpath = a:fullpath

    if s:running_windows
        let fullpath = s:oPath.WinToUnixPath(fullpath)
    endif

    let newPath.pathSegments = split(fullpath, '/')

    let newPath.isDirectory = isdirectory(fullpath)

    return newPath
endfunction

"FUNCTION: oPath.ReadInfoFromDisk(fullpath) {{{3 
"
"
"Throws NERDTree.Path.InvalidArguments exception.
function! s:oPath.ReadInfoFromDisk(fullpath) dict
    let fullpath = a:fullpath

    if s:running_windows
        let fullpath = s:oPath.WinToUnixPath(fullpath)
    endif

    let self.pathSegments = split(fullpath, '/')

    let self.isReadOnly = 0
    if isdirectory(fullpath)
        let self.isDirectory = 1
    elseif filereadable(fullpath)
        let self.isDirectory = 0
        let self.isReadOnly = filewritable(fullpath) == 0
    else
        throw "NERDTree.Path.InvalidArguments Exception: Invalid path = " . fullpath
    endif

    "grab the last part of the path (minus the trailing slash) 
    let lastPathComponent = self.GetLastPathComponent(0)

    "get the path to the new node with the parent dir fully resolved 
    let hardPath = resolve(self.StrTrunk()) . '/' . lastPathComponent

    "if  the last part of the path is a symlink then flag it as such 
    let self.isSymLink = (resolve(hardPath) != hardPath)
    if self.isSymLink
        let self.symLinkDest = resolve(fullpath)

        "if the link is a dir then slap a / on the end of its dest 
        if isdirectory(self.symLinkDest) 
            
            "we always wanna treat MS windows shortcuts as files for
            "simplicity 
            if hardPath !~ '\.lnk$'

                let self.symLinkDest = self.symLinkDest . '/'
            endif
        endif
    endif
endfunction

"FUNCTION: oPath.Refresh() {{{3 
function! s:oPath.Refresh() dict
    call self.ReadInfoFromDisk(self.Str(0))
endfunction

"FUNCTION: oPath.Rename() {{{3 
"
"Renames this node on the filesystem
function! s:oPath.Rename(newPath) dict
    if a:newPath == ''
        throw "NERDTree.Path.InvalidArguments exception. Invalid newPath for renaming = ". a:newPath
    endif

    let success =  rename(self.Str(0), a:newPath)
    if success != 0
        throw "NERDTree.Path.Rename Exception: Could not rename: '" . self.Str(0) . "'" . 'to:' . a:newPath
    endif
    let self.pathSegments = split(a:newPath, '/')
endfunction

"FUNCTION: oPath.Str(esc) {{{3 
"
"Gets the actual string path that this obj represents.
"
"Args:
"esc: if 1 then all the tricky chars in the returned string will be escaped      
function! s:oPath.Str(esc) dict
    let toReturn = '/' . join(self.pathSegments, '/')
    if self.isDirectory && toReturn != '/'
        let toReturn  = toReturn . '/'
    endif

    if a:esc
        let toReturn = escape(toReturn, s:escape_chars)
    endif
    return toReturn
endfunction

"FUNCTION: oPath.StrAbs() {{{3 
"
"Returns a string representing this path with all the symlinks resolved
"
"Return:
"string
function! s:oPath.StrAbs() dict
    return resolve(self.Str(1))
endfunction

"FUNCTION: oPath.StrDisplay() {{{3 
"
"Returns a string that specifies how the path should be represented as a
"string
"
"Return:
"a string that can be used in the view to represent this path
function! s:oPath.StrDisplay() dict
    let toReturn = self.GetLastPathComponent(1)

    if self.isSymLink
        let toReturn .=  ' -> ' . self.symLinkDest
    endif

    if self.isReadOnly
        let toReturn .=  s:tree_RO_str
    endif


    return toReturn
endfunction

"FUNCTION: oPath.StrForEditCmd() {{{3 
"
"Return: the string for this path that is suitable to be used with the :edit
"command
function! s:oPath.StrForEditCmd() dict
    if s:running_windows
        return self.StrForOS(0)
	else
		return self.Str(1)
    endif

endfunction
"FUNCTION: oPath.StrForOS(esc) {{{3 
"
"Gets the string path for this path object that is appropriate for the OS.
"EG, in windows c:\foo\bar
"    in *nix  /foo/bar
"
"Args: 
"esc: if 1 then all the tricky chars in the returned string will be
" escaped. If we are running windows then the str is double quoted instead.
function! s:oPath.StrForOS(esc) dict
    let lead = s:os_slash

    "if we are running windows then slap a drive letter on the front 
    if s:running_windows
        let lead = strpart(getcwd(), 0, 2) . s:os_slash
    endif

    let toReturn = lead . join(self.pathSegments, s:os_slash)

    if a:esc
        if s:running_windows
            let toReturn = '"' .  toReturn . '"'
        else
            let toReturn = escape(toReturn, s:escape_chars)
        endif
    endif
    return toReturn
endfunction

"FUNCTION: oPath.StrTrunk() {{{3 
"Gets the path without the last segment on the end.
function! s:oPath.StrTrunk() dict
    return '/' . join(self.pathSegments[0:-2], '/')
endfunction

"FUNCTION: oPath.WinToUnixPath(pathstr){{{3
"Takes in a windows path and returns the unix equiv
"
"A class level method
"
"Args:
"pathstr: the windows path to convert
function! s:oPath.WinToUnixPath(pathstr) dict
    let toReturn = a:pathstr

    "remove the x:\ of the front
    let toReturn = substitute(toReturn, '^.*:\(\\\|/\)\?', '/', "")

    "convert all \ chars to / 
    let toReturn = substitute(toReturn, '\', '/', "g")

    return toReturn
endfunction

" SECTION: General Functions {{{1
"============================================================
"FUNCTION: s:BufInWindows(bnum){{{2
"[[STOLEN FROM VTREEEXPLORER.VIM]]
"Determine the number of windows open to this buffer number. 
"Care of Yegappan Lakshman.  Thanks! 
"
"Args:
"bnum: the subject buffers buffer number
function! s:BufInWindows(bnum) 
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

"FUNCTION: s:InitNerdTree(dir) {{{2 
"Initialized the NERD tree, where the root will be initialized with the given
"directory
"
"Arg:
"dir: the dir to init the root with
function! s:InitNerdTree(dir)
    let dir = a:dir == '' ? expand('%:p:h') : a:dir
    let dir = resolve(dir)

    if !isdirectory(dir)
        call s:EchoWarning("NERD_Tree: Error reading: " . dir)
        return
    endif

    "if instructed to, then change the vim CWD to the dir the NERDTree is
    "inited in 
    if g:NERDTreeChDirMode != 0
        exec "cd " . dir
    endif

    let t:treeShowHelp = 0
    let t:NERDTreeIgnoreEnabled = 1

    if exists("t:NERDTreeRoot")
        if s:IsTreeOpen()
            call s:CloseTree()
        endif
        unlet t:NERDTreeRoot
    endif

	let path = s:oPath.New(dir)
    let t:NERDTreeRoot = s:oTreeDirNode.New(path)
    call t:NERDTreeRoot.Open()

    call s:CreateTreeWin()

    call s:RenderView()
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
function! s:InstallDocumentation(full_name, revision)
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
        echo "Doc path: " . l:vim_doc_path
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

" SECTION: View Functions {{{1
"============================================================
"FUNCTION: s:CloseTree() {{{2 
"Closes the NERD tree window
function! s:CloseTree()
    if !s:IsTreeOpen()
        throw "NERDTree.view.CloseTree exception: no NERDTree is open"
    endif

    if winnr("$") != 1
        execute s:GetTreeWinNum() . " wincmd w"
        close
        execute "wincmd p"
    else
        :q
    endif
endfunction

"FUNCTION: s:CreateTreeWin() {{{2 
"Inits the NERD tree window. ie. opens it, sizes it, sets all the local
"options etc
function! s:CreateTreeWin()
    "create the nerd tree window 
    let splitLocation = g:NERDTreeWinPos ? "topleft " : "belowright "
    let splitMode = g:NERDTreeSplitVertical ? "vertical " : ""
    let splitSize = g:NERDTreeWinSize 
    let t:NERDTreeWinName = localtime() . s:NERDTreeWinName
    let cmd = splitLocation . splitMode . splitSize . ' new ' . t:NERDTreeWinName
    silent! execute cmd

    setl winfixwidth

    "throwaway buffer options
    setlocal noswapfile
    setlocal buftype=nofile
    setlocal bufhidden=delete 
    setlocal nowrap
    setlocal foldcolumn=0
    setlocal nobuflisted
    setlocal nospell
    iabc <buffer>

    if g:NERDTreeHighlightCursorline
        setlocal cursorline
    endif

    " syntax highlighting
    if has("syntax") && exists("g:syntax_on") && !has("syntax_items")
        call s:SetupSyntaxHighlighting()
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
function! s:DrawTree(curNode, depth, drawText, vertMap, isLastChild)
    if a:drawText == 1

        let treeParts = ''

        "get all the leading spaces and vertical tree parts for this line
        if a:depth > 1
            for j in a:vertMap[0:-2]
                if j == 1
                    let treeParts = treeParts . s:tree_vert . s:tree_wid_strM1
                else
                    let treeParts = treeParts . s:tree_wid_str
                endif
            endfor
        endif

        "get the last vertical tree part for this line which will be different
        "if this node is the last child of its parent
        if a:isLastChild
            let treeParts = treeParts . s:tree_vert_last
        else
            let treeParts = treeParts . s:tree_vert 
        endif


        "smack the appropriate dir/file symbol on the line before the file/dir
        "name itself
        if a:curNode.path.isDirectory
            if a:curNode.isOpen
                let treeParts = treeParts . s:tree_dir_open
            else
                let treeParts = treeParts . s:tree_dir_closed
            endif
        else
            let treeParts = treeParts . s:tree_file
        endif
        let line = treeParts . a:curNode.StrDisplay()

        call setline(line(".")+1, line)
        call cursor(line(".")+1, col("."))
    endif

    "if the node is an open dir, draw its children 
    if a:curNode.path.isDirectory == 1 && a:curNode.isOpen == 1 

        let childNodesToDraw = a:curNode.GetChildrenToDisplay()
        if len(childNodesToDraw) > 0

            "draw all the nodes children except the last 
            let lastIndx = len(childNodesToDraw)-1
            if lastIndx > 0
                for i in childNodesToDraw[0:lastIndx-1]
                    call s:DrawTree(i, a:depth + 1, 1, add(copy(a:vertMap), 1), 0)
                endfor
            endif

            "draw the last child, indicating that it IS the last 
            call s:DrawTree(childNodesToDraw[lastIndx], a:depth + 1, 1, add(copy(a:vertMap), 0), 1)
        endif
    endif
endfunction


"FUNCTION: s:DumpHelp  {{{2
"prints out the quick help 
function! s:DumpHelp()
    let old_h = @h
    if t:treeShowHelp == 1
        let @h=   "\" NERD tree (" . s:NERD_tree_version . ") quickhelp~\n"
        let @h=@h."\" ============================\n"
        let @h=@h."\" File node mappings~\n"
        let @h=@h."\" double-click,\n"
        let @h=@h."\" ". g:NERDTreeMapActivateNode .": open in prev window\n"
        let @h=@h."\" ". g:NERDTreeMapOpenInTab.": open in new tab\n"
        let @h=@h."\" ". g:NERDTreeMapOpenInTabSilent .": open in new tab silently\n"
        let @h=@h."\" middle-click,\n"
        let @h=@h."\" ". g:NERDTreeMapOpenSplit .": open in new window\n"
        let @h=@h."\" ". g:NERDTreeMapExecute.": Execute file\n"

        let @h=@h."\" \n\" ----------------------------\n"
        let @h=@h."\" Directory node mappings~\n"
        let @h=@h."\" double-click,\n"
        let @h=@h."\" ". g:NERDTreeMapActivateNode .": open/close node \n"
        let @h=@h."\" ". g:NERDTreeMapOpenRecursively .": recursively open node\n"
        let @h=@h."\" ". g:NERDTreeMapCloseDir .": close the current dir\n"
        let @h=@h."\" ". g:NERDTreeMapCloseChildren .": close all child nodes of\n"
        let @h=@h."\"    seleted node\n"
        let @h=@h."\" middle-click,\n"
        let @h=@h."\" ". g:NERDTreeMapOpenExpl.": Open netrw for selected\n"
        let @h=@h."\"    node \n"
        let @h=@h."\" ". g:NERDTreeMapOpenExplNewWin .": Open netrw in new window\n"
        let @h=@h."\"    for selected node\n"

        let @h=@h."\" \n\" ----------------------------\n"
        let @h=@h."\" Tree navigation mappings~\n"
        let @h=@h."\" ". g:NERDTreeMapJumpParent .": jump to parent node\n"
        let @h=@h."\" ". g:NERDTreeMapJumpNextSibling .": jump to next sibling node\n"
        let @h=@h."\" ". g:NERDTreeMapJumpPrevSibling .": jump to prev sibling node\n"

        let @h=@h."\" \n\" ----------------------------\n"
        let @h=@h."\" Filesystem mappings~\n"
        let @h=@h."\"  ". g:NERDTreeMapChangeRoot .": change tree root to the\n"
        let @h=@h."\"     selected dir\n"
        let @h=@h."\" ". g:NERDTreeMapChdir .": change the CWD to the\n"
        let @h=@h."\"     selected dir\n"
        let @h=@h."\"  ". g:NERDTreeMapUpdir .": move tree root up a dir\n"
        let @h=@h."\"  ". g:NERDTreeMapUpdirKeepOpen .": move tree root up a dir\n"
        let @h=@h."\"     but leave old root open\n"
        let @h=@h."\"  ". g:NERDTreeMapRefresh .": refresh cursor dir\n"
        let @h=@h."\"  ". g:NERDTreeMapRefreshRoot .": refresh current root\n"
        let @h=@h."\"  ". g:NERDTreeMapFilesystemMenu .": Show filesystem menu\n"

        let @h=@h."\" \n\" ----------------------------\n"
        let @h=@h."\" Tree filtering mappings~\n"
        let @h=@h."\" ". g:NERDTreeMapToggleHidden .": toggle show hidden (" . (g:NERDTreeShowHidden ? "on" : "off") . ")\n"
        let @h=@h."\" ". g:NERDTreeMapToggleFilters .": toggle file filters (" . (t:NERDTreeIgnoreEnabled ? "on" : "off") . ")\n"
        let @h=@h."\" ". g:NERDTreeMapToggleFiles .": toggle show files (" . (g:NERDTreeShowFiles ? "on" : "off") . ")\n"

        let @h=@h."\" \n\" ----------------------------\n"
        let @h=@h."\" Other mappings~\n"
        let @h=@h."\" ". g:NERDTreeMapQuit .": Close the NERDTree window\n"
        let @h=@h."\" ". g:NERDTreeMapHelp .": toggle help\n"
    else
        let @h="\" Press ". g:NERDTreeMapHelp ." for help\n"
    endif

    silent! put h

    let @h = old_h
endfunction
"FUNCTION: s:EchoWarning  {{{2
function! s:EchoWarning(msg)
    echohl warningmsg
    echo a:msg
    echohl normal
endfunction
"FUNCTION: s:FindNodeLineNumber(path){{{2
"Finds the line number for the given tree node
"
"Args:
"treenode: the node to find the line no. for
function! s:FindNodeLineNumber(treenode) 
    "if the node is the root then return the root line no. 
    if t:NERDTreeRoot.Equals(a:treenode)
        return s:FindRootNodeLineNumber()
    endif

    let totalLines = line("$")

    "the path components we have matched so far 
    let pathcomponents = [substitute(t:NERDTreeRoot.path.Str(0), '/ *$', '', '')]
    "the index of the component we are searching for 
    let curPathComponent = 1

    let fullpath = a:treenode.path.Str(0)


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
function! s:FindRootNodeLineNumber() 
    let rootLine = 1
    while getline(rootLine) !~ '^/'
        let rootLine = rootLine + 1
    endwhile
    return rootLine
endfunction

"FUNCTION: s:GetPath(ln) {{{2 
"Gets the full path to the node that is rendered on the given line number
"
"Args:
"ln: the line number to get the path for
"
"Return:
"A path if a node was selected, {} if nothing is selected.
"If the 'up a dir' line was selected then the path to the parent of the
"current root is returned
function! s:GetPath(ln) 
    let line = getline(a:ln)

    "check to see if we have the root node 
    if line =~ '^\/'
        return t:NERDTreeRoot.path
    endif

    " in case called from outside the tree
    if line !~ '^ *[|`]' || line =~ '^$'
        return {}
    endif

    if line == s:tree_up_dir_line
        return s:oPath.New( t:NERDTreeRoot.path.GetDir(0) )
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
    return s:oPath.NewMinimal(curFile)
endfunction 

"FUNCTION: s:GetSelectedNode() {{{2 
"gets the treenode that the cursor is currently over
function! s:GetSelectedNode() 
    try 
        let path = s:GetPath(line("."))
        if path == {}
            return {}
        endif
        return t:NERDTreeRoot.FindNode(path)
    catch /^NERDTree/
        return {}
    endtry
endfunction

function SelectedNode()
    return s:GetSelectedNode()
endf

"FUNCTION: s:GetTreeBufNum()"{{{2
"gets the nerd tree buffer number for this tab
function! s:GetTreeBufNum() 
    if exists("t:NERDTreeWinName")
        return bufnr(t:NERDTreeWinName)
    else
        return -1
    endif
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

"FUNCTION: s:IsTreeOpen()"{{{2
function! s:IsTreeOpen() 
    return s:GetTreeWinNum() != -1
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
        try
            call s:OpenNodeSplit(a:treenode)
        catch /^NERDTree.view.FileOpen/
            echo "NERDTree: Cannot open file, it is already open and modified" 
        endtry
    endif
endfunction

"FUNCTION: s:OpenNodeSplit(treenode)"{{{2
"Open the file/dir represented by the given node in a new window
"
"ARGS:
"treenode: file node to open
function! s:OpenNodeSplit(treenode) 
    call s:PutCursorInTreeWin()

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
    if g:NERDTreeSplitVertical == 1
        let there= g:NERDTreeWinPos ? "wincmd h" : "wincmd l"
        let back= g:NERDTreeWinPos ? "wincmd l" : "wincmd h"
        let right=g:NERDTreeWinPos ? 1 : 0
        let below=0
    else
        let there= g:NERDTreeWinPos ? "wincmd k" : "wincmd j"
        let back= g:NERDTreeWinPos ? "wincmd j" : "wincmd k"
        let right=0
        let below=g:NERDTreeWinPos ? 1 : 0
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
    if (onlyOneWin && g:NERDTreeSplitVertical) || (!onlyOneWin && !g:NERDTreeSplitVertical)
        let splitMode = "vertical"
    endif

    " Open the new window
    try
        exec("silent " . splitMode." sp " . a:treenode.path.StrForEditCmd())
    catch /^Vim\%((\a\+)\)\=:E37/
		call s:PutCursorInTreeWin()
        throw "NERDTree.view.FileOpen exception: ". a:treenode.path.Str(0) ." is already open and modified."
    endtry

    " resize the explorer window if it is larger than the requested size
    exec(there)

    if g:NERDTreeWinSize =~ '[0-9]\+' && winheight("") > g:NERDTreeWinSize
        exec("silent vertical resize ".g:NERDTreeWinSize)
    endif

    wincmd p

    " Restore splitmode settings
    let &splitbelow=savesplitbelow
    let &splitright=savesplitright
endfunction 

"FUNCTION: s:PromptToDelBuffer(bufnum, msg){{{2
"prints out the given msg and, if the user responds by pushing 'y' then the
"buffer with the given bufnum is deleted
"
"Args:
"bufnum: the buffer that may be deleted
"msg: a message that will be echoed to the user asking them if they wish to
"     del the buffer
function! s:PromptToDelBuffer(bufnum, msg) 
    echo a:msg
    if nr2char(getchar()) == 'y'
        exec "silent bdelete " . a:bufnum
    endif
endfunction

"FUNCTION: s:PutCursorOnNode(treenode, is_jump){{{2
"Places the cursor on the line number representing the given node
"
"Args:
"treenode: the node to put the cursor on
"is_jump: 1 if this cursor movement should be counted as a jump by vim
function! s:PutCursorOnNode(treenode, is_jump) 
    let ln = s:FindNodeLineNumber(a:treenode)
    if ln != -1
        if a:is_jump
            mark '
        endif
        call cursor(ln, col("."))
    endif
endfunction

"FUNCTION: s:PutCursorInTreeWin(){{{2
"Places the cursor in the nerd tree window
function! s:PutCursorInTreeWin() 
	if !s:IsTreeOpen()
		throw "NERDTree.view.InvalidOperation Exception: No NERD tree window exists"
	endif

	exec s:GetTreeWinNum() . "wincmd w"
endfunction

"FUNCTION: s:RenderView {{{2 
"The entry function for rendering the tree. Renders the root then calls
"s:DrawTree to draw the children of the root
"
"Args:
function! s:RenderView()
    execute s:GetTreeWinNum() . "wincmd w"

    setlocal modifiable

    "remember the top line of the buffer and the current line so we can
    "restore the view exactly how it was
    let curLine = line(".")
    let curCol = col(".")
    let topLine = line("w0")

    "delete all lines in the buffer (being careful not to clobber a register)  
    :silent 1,$delete _

    call s:DumpHelp()

    "delete the blank line before the help and add one after it 
    call setline(line(".")+1, " ")
    call cursor(line(".")+1, col("."))

    "add the 'up a dir' line 
    call setline(line(".")+1, s:tree_up_dir_line)
    call cursor(line(".")+1, col("."))

    "draw the header line  
    call setline(line(".")+1, t:NERDTreeRoot.path.Str(0))
    call cursor(line(".")+1, col("."))

    "draw the tree 
    call s:DrawTree(t:NERDTreeRoot, 0, 0, [], len(t:NERDTreeRoot.children) == 1)

    "delete the blank line at the top of the buffer
    :silent 1,1delete _

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
function! s:RestoreScreenState()
    if !exists("t:NERDTreeOldTopLine") || !exists("t:NERDTreeOldPos")
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
function! s:SaveScreenState()
    let t:NERDTreeOldPos = getpos(".")
    let t:NERDTreeOldTopLine = line("w0")
endfunction

"FUNCTION: s:SetupSyntaxHighlighting() {{{2 
function! s:SetupSyntaxHighlighting()
    "treeFlags are syntax items that should be invisible, but give clues as to
    "how things should be highlighted
    syn match treeFlag #\~#
    syn match treeFlag #\[RO\]#

    "highlighting for the .. (up dir) line at the top of the tree 
    execute "syn match treeUp #". s:tree_up_dir_line ."#"

    "highlighting for the ~/+ symbols for the directory nodes 
    syn match treeClosable #\~\<#
    syn match treeClosable #\~\.#
    syn match treeOpenable #+\<#
    syn match treeOpenable #+\.#he=e-1

    "highlighting for the tree structural parts 
    syn match treePart #|#
    syn match treePart #`#
    syn match treePartFile #[|`]-#hs=s+1 contains=treePart

    "quickhelp syntax elements 
    syn match treeHelpKey #" \{1,2\}[^ ]*:#hs=s+2,he=e-1
    syn match treeHelpKey #" \{1,2\}[^ ]*,#hs=s+2,he=e-1
    syn match treeHelpTitle #" .*\~#hs=s+2,he=e-1 contains=treeFlag
    syn match treeToggleOn #".*(on)#hs=e-2,he=e-1 contains=treeHelpKey
    syn match treeToggleOff #".*(off)#hs=e-3,he=e-1 contains=treeHelpKey
    syn match treeHelp  #^" .*# contains=treeHelpKey,treeHelpTitle,treeFlag,treeToggleOff,treeToggleOn

    "highlighting for sym links 
    syn match treeLink #[^-| `].* -> #

    "highlighting for readonly files 
    syn match treeRO #[0-9a-zA-Z]\+.*\[RO\]# contains=treeFlag

    "highlighing for directory nodes and file nodes 
    syn match treeDirSlash #/#
    syn match treeDir #[^-| `].*/\([ {}]\{4\}\)*$# contains=treeLink,treeDirSlash,treeOpenable,treeClosable
    syn match treeFile  #|-.*# contains=treeLink,treePart,treeRO,treePartFile
    syn match treeFile  #`-.*# contains=treeLink,treePart,treeRO,treePartFile
    syn match treeCWD #^/.*$# 

    if g:NERDChristmasTree
        hi def link treePart Special
        hi def link treePartFile Type
        hi def link treeFile Macro
        hi def link treeDirSlash Identifier
        hi def link treeClosable Type
    else
        hi def link treePart Normal
        hi def link treePartFile Normal
        hi def link treeFile Normal
        hi def link treeClosable Title
    endif

    hi def link treeHelp String
    hi def link treeHelpKey Identifier
    hi def link treeHelpTitle Macro
    hi def link treeToggleOn Question
    hi def link treeToggleOff WarningMsg

    hi def link treeDir Directory
    hi def link treeUp Directory
    hi def link treeCWD Statement
    hi def link treeLink Title
    hi def link treeOpenable Title
    hi def link treeFlag ignore
    hi def link treeRO WarningMsg

    hi def link NERDTreeCurrentNode Search
endfunction
"FUNCTION: s:StripMarkupFromLine(line){{{2
"returns the given line with all the tree parts stripped off
"
"Args:
"line: the subject line
"removeLeadingSpaces: 1 if leading spaces are to be removed (leading spaces =
"any spaces before the actual text of the node)
function! s:StripMarkupFromLine(line, removeLeadingSpaces) 
    let line = a:line
    "remove the tree parts and the leading space 
    let line = substitute (line,"^" . s:tree_markup_reg . "*","","")

    "strip off any read only flag 
    let line = substitute (line, s:tree_RO_str_reg, "","")

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
function! s:Toggle(dir)
    if exists("t:NERDTreeRoot")
        if !s:IsTreeOpen()
            call s:CreateTreeWin()
            call s:RenderView()

            call s:RestoreScreenState()
        else
            call s:CloseTree()
        endif
    else
        call s:InitNerdTree(a:dir)
    endif
endfunction
"SECTION: Interface bindings {{{1
"============================================================
"FUNCTION: s:ActivateNode() {{{2
"If the current node is a file, open it in the previous window (or a new one
"if the previous is modified). If it is a directory then it is opened.
function! s:ActivateNode()
    if getline(".") == s:tree_up_dir_line
        return s:UpDir(0)
    endif
    let treenode = s:GetSelectedNode()
    if treenode == {} 
        call s:EchoWarning("NERDTree: cannot open selected entry")
        return
    endif

    if treenode.path.isDirectory
        call treenode.ToggleOpen()
        call s:RenderView()
        call s:PutCursorOnNode(treenode, 0)
    else
        let oldwin = winnr()
        wincmd p
        if oldwin == winnr() || (&modified && s:BufInWindows(winbufnr(winnr())) < 2)
            wincmd p
            call s:OpenFileNodeSplit(treenode)
        else
            try
                exec ("edit " . treenode.path.StrForEditCmd())
            catch /^Vim\%((\a\+)\)\=:E37/
				call s:PutCursorInTreeWin()
                echo "NERDTree: Cannot open file, it is already open and modified 1"
            endtry
        endif
    endif
endfunction

"FUNCTION: s:BindMappings() {{{2
function! s:BindMappings()
    " set up mappings and commands for this buffer
    nnoremap <silent> <buffer> <middlerelease> :call <SID>HandleMiddleMouse()<cr>
    nnoremap <silent> <buffer> <leftrelease> <leftrelease>:call <SID>CheckForActivate()<cr>
    nnoremap <silent> <buffer> <2-leftmouse> :call <SID>ActivateNode()<cr>

    exec "nnoremap <silent> <buffer> ". g:NERDTreeMapActivateNode . " :call <SID>ActivateNode()<cr>"
    exec "nnoremap <silent> <buffer> ". g:NERDTreeMapOpenSplit ." :call <SID>OpenEntrySplit()<cr>"


    exec "nnoremap <silent> <buffer> ". g:NERDTreeMapExecute ." :call <SID>ExecuteNode()<cr>"

    exec "nnoremap <silent> <buffer> ". g:NERDTreeMapOpenRecursively ." :call <SID>OpenNodeRecursively()<cr>"

    exec "nnoremap <silent> <buffer> ". g:NERDTreeMapUpdirKeepOpen ." :call <SID>UpDir(1)<cr>"
    exec "nnoremap <silent> <buffer> ". g:NERDTreeMapUpdir ." :call <SID>UpDir(0)<cr>"
    exec "nnoremap <silent> <buffer> ". g:NERDTreeMapChangeRoot ." :call <SID>ChRoot()<cr>"

    exec "nnoremap <silent> <buffer> ". g:NERDTreeMapChdir ." :call <SID>ChCwd()<cr>"

    exec "nnoremap <silent> <buffer> ". g:NERDTreeMapQuit ." :NERDTreeToggle<cr>"

    exec "nnoremap <silent> <buffer> ". g:NERDTreeMapRefreshRoot ." :call <SID>RefreshRoot()<cr>"
    exec "nnoremap <silent> <buffer> ". g:NERDTreeMapRefresh ." :call <SID>RefreshCurrent()<cr>"

    exec "nnoremap <silent> <buffer> ". g:NERDTreeMapHelp ." :call <SID>DisplayHelp()<cr>"
    exec "nnoremap <silent> <buffer> ". g:NERDTreeMapToggleHidden ." :call <SID>ToggleShowHidden()<cr>"
    exec "nnoremap <silent> <buffer> ". g:NERDTreeMapToggleFilters ." :call <SID>ToggleIgnoreFilter()<cr>"
    exec "nnoremap <silent> <buffer> ". g:NERDTreeMapToggleFiles ." :call <SID>ToggleShowFiles()<cr>"

    exec "nnoremap <silent> <buffer> ". g:NERDTreeMapCloseDir ." :call <SID>CloseCurrentDir()<cr>"
    exec "nnoremap <silent> <buffer> ". g:NERDTreeMapCloseChildren ." :call <SID>CloseChildren()<cr>"

    exec "nnoremap <silent> <buffer> ". g:NERDTreeMapFilesystemMenu ." :call <SID>ShowFileSystemMenu()<cr>"

    exec "nnoremap <silent> <buffer> ". g:NERDTreeMapJumpParent ." :call <SID>JumpToParent()<cr>"
    exec "nnoremap <silent> <buffer> ". g:NERDTreeMapJumpNextSibling ." :call <SID>JumpToSibling(1)<cr>"
    exec "nnoremap <silent> <buffer> ". g:NERDTreeMapJumpPrevSibling ." :call <SID>JumpToSibling(0)<cr>"

    exec "nnoremap <silent> <buffer> ". g:NERDTreeMapOpenInTab ." :call <SID>OpenEntryNewTab(0)<cr>"
    exec "nnoremap <silent> <buffer> ". g:NERDTreeMapOpenInTabSilent ." :call <SID>OpenEntryNewTab(1)<cr>"

    exec "nnoremap <silent> <buffer> ". g:NERDTreeMapOpenExpl ." :call <SID>OpenExplorer(0)<cr>"
    exec "nnoremap <silent> <buffer> ". g:NERDTreeMapOpenExplNewWin ." :call <SID>OpenExplorer(1)<cr>"
endfunction

"FUNCTION: s:CheckForActivate() {{{2
"Checks if the click should open the current node, if so then activate() is
"called (directories are automatically opened if the symbol beside them is
"clicked)
function! s:CheckForActivate()
    let currentNode = s:GetSelectedNode()
    if currentNode != {} 
        let startToCur = strpart(getline(line(".")), 0, col("."))
        let char = strpart(startToCur, strlen(startToCur)-1, 1)

        "if they clicked a dir, check if they clicked on the + or ~ sign
        "beside it 
        if currentNode.path.isDirectory
            let reg = '^' . s:tree_markup_reg .'*[' . s:tree_dir_open . s:tree_dir_closed . ']$'
            if startToCur =~ reg
                call s:ActivateNode()
                return
            endif
        endif

        if (g:NERDTreeMouseMode == 2 && currentNode.path.isDirectory) || g:NERDTreeMouseMode == 3
            if char !~ s:tree_markup_reg && startToCur !~ '\/$'
                call s:ActivateNode()
                return
            endif
        endif
    endif
endfunction

" FUNCTION: s:ChCwd() {{{2
function! s:ChCwd() 
    let treenode = s:GetSelectedNode()
    if treenode == {} 
        echo "NERDTree: Select a node first"
        return
    endif

    try
        call treenode.path.ChangeToDir()
    catch /^NERDTree.Path.Change/
        call s:EchoWarning("NERDTree: could not change cwd")
    endtry
endfunction

" FUNCTION: s:ChRoot() {{{2
" changes the current root to the selected one
function! s:ChRoot() 
    let treenode = s:GetSelectedNode()
    if treenode == {} || treenode.path.isDirectory == 0
        echo "NERDTree: Select a directory node first"
        return
    endif

    if treenode.isOpen == 0
        call treenode.Open()
    endif

    let t:NERDTreeRoot = treenode
    
    "change dir to the dir of the new root if instructed to 
    if g:NERDTreeChDirMode == 2
        exec "cd " . treenode.path.StrForEditCmd()
    endif


    call s:RenderView()
    call s:PutCursorOnNode(t:NERDTreeRoot, 0)
endfunction

" FUNCTION: s:CloseChildren() {{{2
" closes all childnodes of the current node
function! s:CloseChildren() 
    let currentNode = s:GetSelectedNode()
    if currentNode == {}
        echo "NERDTree: Select a node first"
        return
    endif

    if currentNode.path.isDirectory == 0
        let currentNode = currentNode.parent
    endif

    if empty(currentNode)
        echo "NERDTree: cannot close children"
    else
        call currentNode.CloseChildren()
        call s:RenderView()
        call s:PutCursorOnNode(currentNode, 0)
    endif
endfunction
" FUNCTION: s:CloseCurrentDir() {{{2
" closes the parent dir of the current node
function! s:CloseCurrentDir() 
    let treenode = s:GetSelectedNode()
    let parent = treenode.parent
    if parent.path.Str(0) == t:NERDTreeRoot.path.Str(0)
        echo "NERDTree: cannot close tree root"
    else
        call treenode.parent.Close()
        call s:RenderView()
        call s:PutCursorOnNode(treenode.parent, 0)
    endif
endfunction

" FUNCTION: s:DeleteNode() {{{2
" if the current node is a file, pops up a dialog giving the user the option
" to delete it
function! s:DeleteNode() 
    let currentNode = s:GetSelectedNode()
    if currentNode == {}
        echo "NERDTree: Put the cursor on a file node first"
        return
    endif

    let confirmed = 0

    if currentNode.path.isDirectory
        let choice =input( "|NERDTree Node Deletor\n" .
                         \ "|==========================================================\n". 
                         \ "|STOP! To delete this entire directory, type 'yes'\n" . 
                         \ "|" . currentNode.path.StrForOS(0) . ": ")
        let confirmed = choice == 'yes'
    else
        echo "|NERDTree Node Deletor\n" .
                         \ "|==========================================================\n". 
                         \ "|Are you sure you wish to delete the node:\n" . 
                         \ "|" . currentNode.path.StrForOS(0) . " (yN):"
        let choice = nr2char(getchar())
        let confirmed = choice == 'y'
    endif


    if confirmed
        try
            call currentNode.Delete()
            call s:RenderView()

            "if the node is open in a buffer, ask the user if they want to
            "close that buffer 
            let bufnum = bufnr(currentNode.path.Str(0))
            if bufnum != -1
                let prompt = "|\n|Node deleted.\n|\n|The file is open in buffer ". bufnum . (bufwinnr(bufnum) == -1 ? " (hidden)" : "") .". Delete this buffer? (yN)"
                call s:PromptToDelBuffer(bufnum, prompt)
            endif

            redraw
        catch /^NERDTree/
            call s:EchoWarning("NERDTree: Could not remove node" )
        endtry
    else
        echo "NERDTree: delete aborted" 
    endif

endfunction

" FUNCTION: s:DisplayHelp() {{{2
" toggles the help display
function! s:DisplayHelp() 
    let t:treeShowHelp = t:treeShowHelp ? 0 : 1
    call s:RenderView()
endfunction

" FUNCTION: s:ExecuteNode() {{{2
function! s:ExecuteNode()
    let treenode = s:GetSelectedNode()
    if treenode == {} || treenode.path.isDirectory
        echo "NERDTree: Select an executable file node first" 
    else
        echo "|NERDTree executor\n" .
           \ "|==========================================================\n". 
           \ "|Complete the command to execute (add arguments etc): \n\n"
        let cmd = treenode.path.StrForOS(1) 
        let cmd = input(':!', cmd . ' ')

        if cmd != ''
            exec ':!' . cmd
        else
            echo "NERDTree: command aborted"
        endif
    endif
endfunction

" FUNCTION: s:HandleMiddleMouse() {{{2
function! s:HandleMiddleMouse() 
    let curNode = s:GetSelectedNode()
    if curNode == {}
        echo "NERDTree: Put the cursor on a node first" 
        return
    endif

    if curNode.path.isDirectory
        call s:OpenExplorer(0)
    else
        call s:OpenEntrySplit()
    endif
endfunction


" FUNCTION: s:InsertNewNode() {{{2
" Adds a new node to the filesystem and then into the tree
function! s:InsertNewNode() 
    let curDirNode = s:GetSelectedNode()
    if curDirNode == {}
        echo "NERDTree: Put the cursor on a node first" 
        return
    endif

    if curDirNode.path.isDirectory == 0
        let curDirNode = curDirNode.parent
    endif

    let newNodeName = input("|NERDTree Node Creator\n" .
                          \ "|==========================================================\n". 
                          \ "|Enter the dir/file name to be created. Dirs end with a '/'\n" . 
                          \ "|", curDirNode.path.Str(0))
    
    if newNodeName == ''
        echo "NERDTree: Node Creation Aborted."
        return
    endif

    try
        let newPath = s:oPath.Create(newNodeName)

        let parentNode = t:NERDTreeRoot.FindNode(newPath.GetPathTrunk())

        let newTreeNode = s:oTreeFileNode.New(newPath)
        if parentNode.isOpen == 1 || !empty(parentNode.children) 
            call parentNode.AddChild(newTreeNode, 1)
            call s:RenderView()
            call s:PutCursorOnNode(newTreeNode, 1)
        endif
    catch /^NERDTree/
        call s:EchoWarning("NERDTree: Node Not Created.")
    endtry
endfunction

" FUNCTION: s:JumpToParent() {{{2
" moves the cursor to the parent of the current node
function! s:JumpToParent() 
    let currentNode = s:GetSelectedNode()
    if !empty(currentNode)
        if !empty(currentNode.parent) 
            call s:PutCursorOnNode(currentNode.parent, 1)
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
function! s:JumpToSibling(forward) 
    let currentNode = s:GetSelectedNode()
    if !empty(currentNode)
        let sibling = currentNode.FindSibling(a:forward)
        if !empty(sibling)
            call s:PutCursorOnNode(sibling, 1)
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
        exec "tabedit " . treenode.path.StrForEditCmd()
        if a:stayCurrentTab
            exec "tabnext " . curTabNr
        endif
    else
        echo "NERDTree: select a node first"
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
        echo "NERDTree: select a node first"
    endif
endfunction 

" FUNCTION: s:OpenExplorer(split) {{{2
function! s:OpenExplorer(split) 
    let treenode = s:GetSelectedNode()
    if treenode != {}
        if treenode.path.isDirectory == 0
            let treenode = treenode.parent
        endif
        if a:split == 1
            call s:OpenDirNodeSplit(treenode)
        else
            let oldwin = winnr()
            wincmd p
            if oldwin == winnr() || (&modified && s:BufInWindows(winbufnr(winnr())) < 2)
                wincmd p
                call s:OpenDirNodeSplit(treenode)
            else
                exec ("edit " . treenode.path.StrForEditCmd())
            endif
        endif
    else
        echo "NERDTree: select a node first"
    endif
    
endfunction

" FUNCTION: s:OpenNodeRecursively() {{{2
function! s:OpenNodeRecursively() 
    let treenode = s:GetSelectedNode()
    if treenode == {} || treenode.path.isDirectory == 0
        echo "NERDTree: Select a directory node first" 
    else
        echo "Recursively opening node. This could take a while..."
        call treenode.OpenRecursively()
        call s:RenderView()
        redraw
        echo "Recursively opening node. This could take a while... FINISHED"
    endif
    
endfunction

" FUNCTION: s:RefreshRoot() {{{2
" Reloads the current root. All nodes below this will be lost and the root dir
" will be reloaded.
function! s:RefreshRoot() 
    echo "NERDTree: Refreshing the root node. This could take a while..."
    call t:NERDTreeRoot.Refresh()
    call s:RenderView()
    redraw
    echo "NERDTree: Refreshing the root node. This could take a while... FINISHED"
endfunction

" FUNCTION: s:RefreshCurrent() {{{2
" refreshes the root for the current node
function! s:RefreshCurrent() 
    let treenode = s:GetSelectedNode()
    if treenode == {} 
        echo "NERDTree: Refresh failed. Select a node first"
        return
    endif

    let curDir = treenode.path.GetDir(1)
    let parentNode = t:NERDTreeRoot.FindNode(s:oPath.New(curDir))
    if parentNode == {}
        echo "NERDTree: cannot refresh selected dir"
        return
    endif

    echo "NERDTree: Refreshing node. This could take a while..."
    call parentNode.Refresh()
    call s:RenderView()
    redraw
    echo "NERDTree: Refreshing node. This could take a while... FINISHED"
endfunction
" FUNCTION: s:RenameCurrent() {{{2
" allows the user to rename the current node
function! s:RenameCurrent() 
    let curNode = s:GetSelectedNode()
    if curNode == {}
        echo "NERDTree: Put the cursor on a node first" 
        return
    endif

    let newNodePath = input("|NERDTree Node Renamer\n" .
                          \ "|==========================================================\n". 
                          \ "|Enter the new path for the node:                          \n" . 
                          \ "|", curNode.path.Str(0))
    
    if newNodePath == ''
        echo "NERDTree: Node Renaming Aborted."
        return
    endif

    let newNodePath = substitute(newNodePath, '\/$', '', '')

    try
        let bufnum = bufnr(curNode.path.Str(0))

        call curNode.Rename(newNodePath)
        call s:RenderView()

        "if the node is open in a buffer, ask the user if they want to
        "close that buffer 
        if bufnum != -1
            let prompt = "|\n|Node renamed.\n|\n|The old file is open in buffer ". bufnum . (bufwinnr(bufnum) == -1 ? " (hidden)" : "") .". Delete this buffer? (yN)"
            call s:PromptToDelBuffer(bufnum, prompt)
        endif

        call s:PutCursorOnNode(curNode, 1)

        redraw
    catch /^NERDTree/
        call s:EchoWarning("NERDTree: Node Not Renamed.")
    endtry
endfunction

" FUNCTION: s:ShowFileSystemMenu() {{{2
function! s:ShowFileSystemMenu() 
    let curNode = s:GetSelectedNode()
    if curNode == {}
        echo "NERDTree: Put the cursor on a node first" 
        return
    endif


    echo "|NERDTree Filesystem Menu\n" .
       \ "|==========================================================\n". 
       \ "|Select the desired operation:                             \n" . 
       \ "| (1) - Add a childnode\n".
       \ "| (2) - Rename the current node\n".
       \ "| (3) - Delete the current node\n\n"

    let choice = nr2char(getchar())

    if choice == 1
        call s:InsertNewNode()
    elseif choice == 2
        call s:RenameCurrent()
    elseif choice == 3
        call s:DeleteNode()
    endif
endfunction

" FUNCTION: s:ToggleIgnoreFilter() {{{2
" toggles the use of the NERDTreeIgnore option 
function! s:ToggleIgnoreFilter() 
    let t:NERDTreeIgnoreEnabled = !t:NERDTreeIgnoreEnabled
    call s:RenderView()
endfunction

" FUNCTION: s:ToggleShowFiles() {{{2
" toggles the display of hidden files
function! s:ToggleShowFiles() 
    let g:NERDTreeShowFiles = !g:NERDTreeShowFiles

    let currentDir = s:GetSelectedNode()
    if currentDir != {} && currentDir.Equals(t:NERDTreeRoot) == 0
        if currentDir.path.isDirectory == 0
            let currentDir = currentDir.parent
        endif
    endif

    call s:RenderView()

    if currentDir != {}
        call s:PutCursorOnNode(currentDir, 0)
        normal zz
    endif
endfunction

" FUNCTION: s:ToggleShowHidden() {{{2
" toggles the display of hidden files
function! s:ToggleShowHidden() 
    let g:NERDTreeShowHidden = !g:NERDTreeShowHidden
    call s:RenderView()
endfunction

"FUNCTION: s:UpDir(keepState) {{{2
"moves the tree up a level
"
"Args:
"keepState: 1 if the current root should be left open when the tree is
"re-rendered
function! s:UpDir(keepState) 
    let cwd = t:NERDTreeRoot.path.Str(0)
    if cwd == "/" || cwd =~ '^[^/]..$'
        echo "NERDTree: already at top dir"
    else
        if !a:keepState
            call t:NERDTreeRoot.Close()
        endif

        let oldRoot = t:NERDTreeRoot

        if empty(t:NERDTreeRoot.parent)
            let path = t:NERDTreeRoot.path.GetPathTrunk()
            let newRoot = s:oTreeDirNode.New(path)
            call newRoot.Open()
            call newRoot.TransplantChild(t:NERDTreeRoot)
            let t:NERDTreeRoot = newRoot
        else
            let t:NERDTreeRoot = t:NERDTreeRoot.parent

        endif

        call s:RenderView()
        call s:PutCursorOnNode(oldRoot, 0)
    endif
endfunction


" SECTION: Doc installation call {{{1
silent call s:InstallDocumentation(expand('<sfile>:p'), s:NERD_tree_version)
"============================================================
finish
" SECTION: The help file {{{1 
"=============================================================================
" Title {{{2
" ============================================================================
=== START_DOC
*NERD_tree.txt*   A tree explorer plugin that owns            #version#





    ________  ________   _   ____________  ____     __________  ____________~
   /_  __/ / / / ____/  / | / / ____/ __ \/ __ \   /_  __/ __ \/ ____/ ____/~
    / / / /_/ / __/    /  |/ / __/ / /_/ / / / /    / / / /_/ / __/ / __/   ~
   / / / __  / /___   / /|  / /___/ _, _/ /_/ /    / / / _, _/ /___/ /___   ~
  /_/ /_/ /_/_____/  /_/ |_/_____/_/ |_/_____/    /_/ /_/ |_/_____/_____/   ~


                              Reference Manual~




==============================================================================
CONTENTS {{{2                                         *NERD_tree-contents* 

    1.Intro...................................|NERD_tree|
    2.Functionality provided..................|NERD_tree-functionality|
        2.1 Commands..........................|NERD_tree-commands|
        2.2 NERD tree mappings................|NERD_tree-mappings|
        2.3 The filesystem menu...............|NERD_tree-filesys-menu|
    3.Customisation...........................|NERD_tree-customisation|
        3.1 Customisation summary.............|NERD_tree-cust-summary|
        3.2 Customisation details.............|NERD_tree-cust-details|
    4.TODO list...............................|NERD_tree-todo|
    5.The Author..............................|NERD_tree-author|
    6.Changelog...............................|NERD_tree-changelog|
    7.Credits.................................|NERD_tree-credits|

==============================================================================
                                                                   *NERD_tree*
1. Intro {{{2 ~

What is this "NERD tree"??

The NERD tree allows you to explore your filesystem and to open files and
directories. It presents the filesystem to you in the form of a tree which you
manipulate with the keyboard and/or mouse. It also allows you to perform
simple filesystem operations so you can alter the tree dynamically.

The following features and functionality are provided by the NERD tree:
    * Files and directories are displayed in a hierarchical tree structure
    * Different highlighting is provided for the following types of nodes:
        * files
        * directories
        * sym-links
        * windows .lnk files
        * read-only files
    * Many (customisable) mappings are provided to manipulate the tree:
        * Mappings to open/close/explore directory nodes
        * Mappings to open files in new/existing windows/tabs     
        * Mappings to change the current root of the tree 
        * Mappings to navigate around the tree 
        * ...
    * Most NERD tree navigation can also be done with the mouse  
    * Dynamic customisation of tree content
        * custom file filters to prevent e.g. vim backup files being displayed
        * optional displaying of hidden files (. files)
        * files can be "turned off" so that only directories are displayed
    * A textual filesystem menu is provided which allows you to create new
      directory nodes and create/delete/rename file nodes
    * The position and size of the NERD tree window can be customised 
    * The order in which the nodes in the tree are listed can be customised.
    * A model of your filesystem is created/maintained as you explore it. This
      has several advantages:
        * All filesystem information is cached and is only re-read on demand
        * If you revisit a part of the tree that you left earlier in your
          session, the directory nodes will be opened/closed as you left them       
    * The script remembers the cursor position and window position in the NERD
      tree so you can toggle it off (or just close the tree window) and then
      reopen it (with NERDTreeToggle) the NERD tree window will appear EXACTLY
      as you left it
    * You can have a separate NERD tree for each tab   

==============================================================================
                                                     *NERD_tree-functionality*
2. Functionality provided {{{2 ~

------------------------------------------------------------------------------
                                                          *NERD_tree-commands*
2.1. Commands {{{3 ~

:NERDTree [start-directory]                                 *:NERDTree*
                Opens a fresh NERD tree in [start-directory] or the current
                directory if [start-directory] isn't specified.
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

When the cursor is in the NERD tree window a number of mappings are available
to use the tree. They are listed below along with the option name that can be
used to customise each mapping.

To change a mapping simply set the mapping option in your |vimrc|. Eg >
    let g:NERDTreeMapOpenSplit = 'i'
<

Mapping                     Default  Description~
                            Key~

NERDTreeMapQuit             q        Closes the NERDTree window
NERDTreeMapActivateNode     o        If the cursor is on a file, this file is
                                     opened in the previous window. If the
                                     cursor is on a directory, the directory
                                     node is expanded in the tree.
NERDTreeMapOpenRecursively  O        Applies to dirs. Recursively opens the
                                     selected directory. This could take a
                                     while to complete so be prepared to go
                                     grab a cup of tea.  Only opens dirs that
                                     aren't filtered out by file filters or
                                     the hidden files filter.
NERDTreeMapOpenSplit        <tab>    Only applies to files. Opens the selected
                                     file in a new split window. 
NERDTreeMapOpenInTab        t        Opens the selected node in a new tab. If
                                     a dir is selected then an explorer for
                                     that dir will be opened.
NERDTreeMapOpenInTabSilent  T        Same as 't' but keeps the focus on the
                                     current tab
NERDTreeMapCloseDir         x        Closes the directory that the
                                     cursor is inside.
NERDTreeMapCloseChildren    X        Closes all children (recursively) of the
                                     current node
NERDTreeMapChangeRoot       C        Only applies to directories.  Changes the
                                     current root of the NERD tree to the
                                     selected directory.
NERDTreeMapChdir            cd       Changes the current working directory to
                                     the directory of the selected node.
NERDTreeMapUpdir            u        Change the root of the tree up one
                                     directory.
NERDTreeMapUpdirKeepOpen    U        Same as 'u' except the old root is left 
                                     open.
NERDTreeMapRefresh          r        Recursively refreshes the directory that
                                     the cursor is currently inside. If the
                                     cursor is on a directory node, this
                                     directory is refreshed.
NERDTreeMapRefreshRoot      R        Recursively refreshes the current root of
                                     the tree... this could take a while for
                                     large trees.
NERDTreeMapJumpParent       p        Moves the cursor to parent directory of
                                     the directory it is currently inside.
NERDTreeMapJumpNextSibling  s        Moves the cursor to next sibling of the
                                     current node.
NERDTreeMapJumpPrevSibling  S        Moves the cursor to previous sibling of
                                     the current node.
NERDTreeMapToggleHidden     H        Toggles whether hidden files are shown
                                     or not.
NERDTreeMapToggleFilters    f        Toggles whether the file filters (as
                                     specified in the |NERDTreeIgnore| option)
                                     are used.
NERDTreeMapToggleFiles      F        Toggles the |NERDTreeShowFiles| option,
                                     causing files to be hidden if they are
                                     currently displayed and vice versa.   
NERDTreeMapOpenExpl         e        If the cursor is on a directory node,
                                     this directory is opened in a file
                                     explorer. If it is on a file, the
                                     file-node's parent directory is opened in
                                     a file explorer. The file explorer is
                                     always opened in the previous window.
NERDTreeMapOpenExplNewWin   E        Like 'e' except the file explorer is
                                     opened in a new split window.
NERDTreeMapFilesystemMenu   m        Displays the filesystem menu see
                                     |NERD_tree-filesys-menu|.
NERDTreeMapExecute          !        Executes the current file node after
                                     prompting the user for args.
NERDTreeMapHelp             ?        Toggles the display of the quick help at
                                     the top of the tree.

The following mouse mappings are available:

Key             Description~

double click    Has the same effect as the 'o' map.

middle click    Has a different effect when used on a file and a dir: For
                files it is the same as the '<tab>' map, for directories it is
                the same as 'e' map.


Additionally, directories can be opened and closed by clicking the '+' and '~'
symbols on their left.

------------------------------------------------------------------------------
                                                      *NERD_tree-filesys-menu*
2.3. The filesystem menu {{{3 ~

The purpose of the filesystem menu is to allow you to perform basic filesystem
operations quickly from the NERD tree rather than the console.  

The filesystem menu can be accessed with 'm' mapping and has three supported
operations: >
    1. Adding nodes.
    2. Renaming nodes.
    3. Deleting nodes.
<
1. Adding nodes:
To add a node move the cursor onto (or anywhere inside) the directory you wish
to create the new node inside. Select the 'add node' option from the
filesystem menu and type a filename. If the filename you type ends with a '/'
character then a directory will be created. Once the operation is completed,
the cursor is placed on the new node.

2. Renaming nodes:
To rename a node, put the cursor on it and select the 'rename' option from the
filesystem menu.  Enter the new name for the node and it will be renamed. If
the old file is open in a buffer, you will be asked if you wish to delete that
buffer. Once the operation is complete the cursor will be placed on the
renamed node.

3. Deleting nodes:
To delete a node put the cursor on it and select the 'delete' option from the
filesystem menu. After confirmation the node will be deleted. If a file is
deleted but still exists as a buffer you will be given the option to delete
that buffer. 

==============================================================================
                                                     *NERD_tree-customisation*
3. Customisation {{{2 ~


------------------------------------------------------------------------------
                                                      *NERD_tree-cust-summary*
3.1. Customisation summary {{{3 ~

The script provides the following options that can customise the behaviour the
NERD tree. These options should be set in your vimrc.

|loaded_nerd_tree|              Turns off the script.

|NERDChristmasTree|             Tells the NERD tree to make itself colourful
                                and pretty.

|NERDTreeChDirMode|             Tells the NERD tree if/when it should change
                                vim's current working directory.

|NERDTreeHighlightCursorline|   Tell the NERD tree whether to highlight the
                                current cursor line.

|NERDTreeIgnore|                Tells the NERD tree which files to ignore.

|NERDTreeMouseMode|             Tells the NERD tree how to handle mouse
                                clicks.

|NERDTreeShowFiles|             Tells the NERD tree whether to display files
                                in the tree on startup.

|NERDTreeShowHidden|            Tells the NERD tree whether to display hidden
                                files on startup.

|NERDTreeSortOrder|             Tell the NERD tree how to sort the nodes in
                                the tree.

|NERDTreeSplitVertical|         Tells the script whether the NERD tree should
                                be created by splitting the window vertically
                                or horizontally.

|NERDTreeWinPos|                Tells the script where to put the NERD tree
                                window.
                               

|NERDTreeWinSize|               Sets the window size when the NERD tree is
                                opened.

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
                                                           *NERDChristmasTree*
Values: 0 or 1.
Default: 1.

If this option is set to 1 then some extra syntax highlighting elements are
added to the nerd tree to make it more colourful.

Set it to 0 for a more vanilla looking tree.

------------------------------------------------------------------------------
                                                           *NERDTreeChDirMode*                

Values: 0, 1 or 2.
Default: 1.

Use this option to tell the script when (if at all) to change the current
working directory (CWD) for vim.

If it is set to 0 then the CWD is never changed by the NERD tree.

If set to 1 then the CWD is changed when the NERD tree is first loaded to the
directory it is initialized in. For example, if you start the NERD tree with >
    :NERDTree /home/marty/foobar
<
then the CWD will be changed to /home/marty/foobar and will not be changed
again unless you init another NERD tree with a similar command.

If the option is set to 2 then it behaves the same as if set to 1 except that
the CWD is changed whenever the tree root is changed. For example, if the CWD
is /home/marty/foobar and you make the node for /home/marty/foobar/baz the new
root then the CWD will become /home/marty/foobar/baz.

Note to windows users: it is highly recommended that you have this option set
to either 1 or 2 or else the script wont function properly if you attempt to
open a NERD tree on a different drive to the one vim is currently in.

Authors note: at work i have this option set to 1 because i have a giant ctags
file in the root dir of my project. This way i can initialise the NERD tree
with the root dir of my project and always have ctags available to me --- no
matter where i go with the NERD tree.

------------------------------------------------------------------------------
                                                 *NERDTreeHighlightCursorline*
Values: 0 or 1.
Default: 1.

If set to 1, the current cursor line in the NERD tree buffer will be
highlighted. This is done using the |cursorline| option.

------------------------------------------------------------------------------
                                                              *NERDTreeIgnore*                
Values: a list of regular expressions.
Default: ['\~$'].

This option is used to specify which files the NERD tree should ignore.  It
must be a list of regular expressions. When the NERD tree is rendered, any
files/dirs that match any of the regex's in NERDTreeIgnore wont be displayed. 

For example if you put the following line in your vimrc: >
    let NERDTreeIgnore=['.vim$', '\~$']
<
then all files ending in .vim or ~ will be ignored. 

Note: to tell the NERD tree not to ignore any files you must use the following
line: >
    let NERDTreeIgnore=[]
<

The file filters can be turned on and off dynamically with the f mapping.

------------------------------------------------------------------------------
                                                           *NERDTreeMouseMode*                
Values: 0, 1 or 2.
Default: 1.

If set to 1 then a double click on a node is required to open it. 
If set to 2 then a single click will open directory nodes, while a double
click will still be required for file nodes.
If set to 3 then a single click will open any node.

Note: a double click anywhere on a line that a tree node is on will
activate it, but all single-click activations must be done on name of the node
itself. For example, if you have the following node: >
    | | |-application.rb
<
then (to single click activate it) you must click somewhere in
'application.rb'.

------------------------------------------------------------------------------
                                                           *NERDTreeShowFiles*            
Values: 0 or 1.
Default: 1.

If this option is set to 1 then files are displayed in the NERD tree. If it is
set to 0 then only directories are displayed.

This option can be toggles dynamically with the F mapping and is useful for
drastically shrinking the tree when you are navigating to a different part of
the tree.

This option can be used in conjunction with the e, middle-click and E mappings
to make the NERD tree function similar to windows explorer.

------------------------------------------------------------------------------
                                                          *NERDTreeShowHidden*            
Values: 0 or 1.
Default: 0.

This option tells vim whether to display hidden files by default. This option
can be dynamically toggled with the D mapping see |NERD_tree_mappings|.
Use one of the follow lines to set this option: >
    let NERDTreeShowHidden=0
    let NERDTreeShowHidden=1
<
                                                       
------------------------------------------------------------------------------
                                                           *NERDTreeSortOrder*
Values: a list of regular expressions.
Default: ['\/$', '*', '\.swp$',  '\.bak$', '\~$']

This option is set to a list of regular expressions which are used to
specify the order of nodes under their parent.

For example, if the option is set to: >
    ['\.vim$', '\.c$', '\.h$', '*', 'foobar']
<
then all .vim files will be placed at the top, followed by all .c files then
all .h files. All files containing the string 'foobar' will be placed at the
end.  The star is a special flag: it tells the script that every node that
doesnt match any of the other regexps should be placed here.

If no star is present in NERDTreeSortOrder then one is automatically appended
to the array.

The regex '\/$' should be used to match directory nodes.

After this sorting is done, the files in each group are sorted alphabetically.

Other examples: >
    (1) ['*', '\/$']
    (2) []
    (3) ['\/$', '\.rb$', '\.php$', '*', '\.swp$',  '\.bak$', '\~$']
<
1. Directories will appear last, everything else will appear above.
2. Every will simply appear in alphabetical order.
3. Dirs will appear first, then ruby and php. Swap files, bak files and vim
   backup files will appear last with everything else preceding them.

------------------------------------------------------------------------------
                                                       *NERDTreeSplitVertical*
Values: 0 or 1.
Default: 1.

This option, along with |NERDTreeWinPos|, is used to determine where the NERD
tree window appears. 

If it is set to 1 then the NERD tree window will appear on either the left or
right side of the screen (depending on the |NERDTreeWinPos| option).

If it set to 0 then the NERD tree window will appear at the top of the screen.

------------------------------------------------------------------------------
                                                              *NERDTreeWinPos*
Values: 0 or 1.
Default: 1.

This option works in conjunction with the |NERDTreeSplitVertical| option to
determine where NERD tree window is placed on the screen.

If the option is set to 1 then the NERD tree will appear on the left or top of
the screen (depending on the value of |NERDTreeSplitVertical|). If set to 0,
the window will appear on the right or bottom of the screen. 

This option is makes it possible to use two different explorer type
plugins simultaneously. For example, you could have the taglist plugin on the
left of the window and the NERD tree on the right.

------------------------------------------------------------------------------
                                                             *NERDTreeWinSize*
Values: a positive integer.
Default: 31.

This option is used to change the size of the NERD tree when it is loaded.

==============================================================================
                                                              *NERD_tree-todo*
4. TODO list {{{2 ~

Window manager integration?

==============================================================================
                                                            *NERD_tree-author*
5. The Author {{{2 ~

The author of the NERD tree is a terrible terrible monster called Martyzilla
who gobbles up small children with milk and sugar for breakfast. He has an odd
love/hate relationship with computers (but monsters hate everything by nature
you know...) which can be awkward for him since he is a pro computer nerd for
a living.

He can be reached at martin_grenfell at msn.com. He would love to hear from
you, so feel free to send him suggestions and/or comments about this plugin.
Don't be shy --- the worst he can do is slaughter you and stuff you in the
fridge for later ;)

==============================================================================
                                                         *NERD_tree-changelog*
6. Changelog {{{2 ~

2.2.2
    - More bugfixes... doh.

2.2.1
    - Bug fix that was causing an exception when closing the nerd tree. Thanks
      to Tim carey-smith and Yu Jun for pointing this out.

2.2.0
    - Now 'cursorline' is set in the NERD tree buffer by default. See :help
      NERDTreeHighlightCursorline for how to disable it.

2.1.2
    - Stopped the script from clobbering the 1,2,3 .. 9 registers.
    - Made it "silent!"ly delete buffers when renaming/deleting file nodes.
    - Minor correction to the doc
    - Fixed a bug when refreshing that was occurring when the node you
      refreshed had been deleted externally.
    - Fixed a bug that was occurring when you open a file that is already open
      and modified.

2.1.1
    - Added a bit more info about the buffers you are prompted to delete when
      renaming/deleting nodes from the filesystem menu that are already loaded
      into buffers.
    - Refactoring and bugfixes

2.1.0
    - Finally removed the blank line that always appears at the top of the
      NERDTree buffer
    - Added NERDTreeMouseMode option. If set to 1, then a double click is
      required to activate all nodes, if set to 2 then a single click will
      activate directory nodes, if set to 3 then a single click will activate
      all nodes.
    - Now if you delete a file node and have it open in a buffer you are given
      the option to delete that buffer as well. Similarly if you rename a file
      you are given the option to delete any buffers containing the old file
      (if any exist)
    - When you rename or create a node, the cursor is now put on the new node,
      this makes it easy immediately edit  the new file.
    - Fixed a bug with the ! mapping that was occurring on windows with paths
      containing spaces.
    - Made all the mappings customisable. See |NERD_tree-mappings| for
      details. A side effect is that a lot of the "double mappings" have
      disappeared. E.g 'o' is now the key that is used to activate a node,
      <CR> is no longer mapped to the same.
    - Made the script echo warnings in some places rather than standard echos
    - Insane amounts of refactoring all over the place.

2.0.0
    - Added two new NERDChristmasTree decorations. First person to spot them
      and email me gets a free copy of the NERDTree.
    - Made it so that when you jump around the tree (with the p, s and S
      mappings) it is counted as a jump by vim. This means if you, eg, push
      'p' one too many times then you can go `` or ctrl-o.
    - Added a new option called NERDTreeSortOrder which takes an array of
      regexs and is used to determine the order that the treenodes are listed
      in. Go :help NERDTreeSortOrder for details.
    - Removed the NERDTreeSortDirs option because it is consumed by
      NERDTreeSortOrder
    - Added the 'i' mapping which is the same as <tab> but requires less
      effort to reach.
    - Added the ! mapping which is  used to execute file in the tree (after it
      prompts you for arguments etc)


==============================================================================
7. Credits {{{2 ~

Thanks to Tim Carey-Smith for testing/using the NERD tree from the first
pre-beta version, for his many suggestions and for his constant stream of bug
complaints.

Thanks to Vigil for trying it out before the first release :) and suggesting
that mappings to open files in new tabs should be implemented.

Thanks to Nick Brettell for testing, fixing my spelling and suggesting i put a
    .. (up a directory)
line in the gui.

Thanks to Thomas Scott Urban - the author of the vtreeexplorer plugin - whose
gui code i borrowed from.

Thanks to Terrance Cohen for pointing out a bug where the script was changing
vims CWD all over the show.

Thanks to Yegappan Lakshmanan (author of Taglist and other orgasmically
wonderful plugins) for telling me how to fix a bug that was causing vim to go
into visual mode everytime you double clicked a node :)

Thanks to Jason Mills for sending me a fix that allows windows paths to use
forward slashes as well as backward.

Thanks to Michael Geddes (frogonwheels on #vim at freenode) for giving me some
tips about syntax highlighting when i was doing highlighting for the
quickhelp.

Thanks to Yu Jun for emailing me about a bug that was occurring when closing
the tree.

=== END_DOC
" vim: set ts=4 sw=4 foldmethod=marker foldmarker={{{,}}} foldlevel=2:
