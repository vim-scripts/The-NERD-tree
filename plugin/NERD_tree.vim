" vim global plugin that provides a nice tree explorer
" Last Change:  22 jan 2007
" Maintainer:   Martin Grenfell <martin_grenfell at msn dot com>
let s:NERD_tree_version = '1.3.1'

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
function s:InitVariable(var, value)
    if !exists(a:var)
        exec 'let ' . a:var . ' = ' . "'" . a:value . "'"
        return 1
    endif
    return 0
endfunction

"SECTION: Init variable calls {{{2 
call s:InitVariable("g:NERDTreeChDirMode", 1)
if !exists("g:NERDTreeIgnore")
    let g:NERDTreeIgnore = ['\~$']
endif
call s:InitVariable("g:NERDTreeShowHidden", 0)
call s:InitVariable("g:NERDTreeShowFiles", 1)
call s:InitVariable("g:NERDTreeSortDirs", 0)
call s:InitVariable("g:NERDTreeSplitVertical", 1)
call s:InitVariable("g:NERDTreeWinPos", 1)
call s:InitVariable("g:NERDTreeWinSize", 30)

let s:running_windows = has("win16") || has("win32") || has("win64")

"init the shell command that will be used to remove dir trees 
"
"Note: the space after the command is important
if s:running_windows
    call s:InitVariable("g:NERDRemoveDirCmd", 'rmdir /s /q ')
else
    call s:InitVariable("g:NERDRemoveDirCmd", 'rm -rf ')
end


" SECTION: Script level variable declaration{{{2
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
end


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
"CLASS: oTreeNode {{{2
"============================================================
let s:oTreeNode = {} 
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
"
"Throws a NERDTree.IllegalOperation exception if called a filenode.
"
"Closes this directory, removes all the child nodes.
function s:oTreeNode.Close() dict
    if self.path.isDirectory != 1
        throw "NERDTree.IllegalOperation Exception: Cannot perform oTreeNode.Close() on a file node"
    endif
    let self.isOpen = 0
endfunction

"FUNCTION: oTreeNode.CloseChildren {{{3 
"Assumes this node is a directory node.
"
"Throws a NERDTree.IllegalOperation exception if called a filenode.
"
"Closes all the child dir nodes of this node 
function s:oTreeNode.CloseChildren() dict
    if self.path.isDirectory != 1
        throw "NERDTree.IllegalOperation Exception: Cannot perform oTreeNode.Close() on a file node"
    endif
    for i in self.children
        if i.path.isDirectory
            call i.Close()
            call i.CloseChildren()
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
    return self.path.GetPath(1) == a:treenode.path.GetPath(1)
endfunction

"FUNCTION: oTreeNode.FindNode(path) {{{3 
"Will find one of the children (recursively) that has a full path of a:path
"
"Args:
"path: a path object
function s:oTreeNode.FindNode(path) dict
    if a:path.Equals(self.path)
        return self
    endif
    if stridx(a:path.GetPath(1), self.path.GetPath(1), 0) == -1
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
    if self.path.isDirectory != 1
        throw "NERDTree.IllegalOperation Exception: Cannot perform oTreeNode.GetChildDirs() on a file node"
    endif

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
    if self.path.isDirectory != 1
        throw "NERDTree.IllegalOperation Exception: Cannot perform oTreeNode.GetChildFiles() on a file node"
    endif
    let toReturn = []
    for i in self.children
        if i.path.isDirectory == 0
            call add(toReturn, i)
        endif
    endfor
    return toReturn
endfunction

"FUNCTION: oTreeNode.GetChildrenToDisplay() {{{3 
"
"Assumes this node is a dir.
"
"Returns a list of children to display for this node, in the correct order
"
"Return:
"an array of treenodes
function s:oTreeNode.GetChildrenToDisplay() dict
    if self.path.isDirectory != 1
        throw "NERDTree.IllegalOperation Exception: Cannot perform oTreeNode.GetChildrenToDisplay() on a file node"
    endif

    let toReturn = []
    for i in self.children
        if i.path.Ignore() == 0
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
    return self.path.GetDisplayString()
endfunction

"FUNCTION: oTreeNode.GetChild(path) {{{3 
"Returns child node of this node that has the given path or {} if no such node
"exists.
"
"This function doesnt not recurse into child dir nodes
"
"Args:
"path: a path object
function s:oTreeNode.GetChild(path) dict
    if self.path.isDirectory != 1
        throw "NERDTree.IllegalOperation Exception: Cannot perform oTreeNode.GetChild() on a file node"
    endif
    if stridx(a:path.GetPath(1), self.path.GetPath(1), 0) == -1
        return {}
    endif

    let index = self.GetChildIndex(a:path)
    if index == -1
        return {}
    else
        return self.children[index]
    endif

endfunction

"FUNCTION: oTreeNode.GetChildIndex(path) {{{3 
"Returns the index of the child node of this node that has the given path or
"-1 if no such node exists.
"
"This function doesnt not recurse into child dir nodes
"
"Args:
"path: a path object
function s:oTreeNode.GetChildIndex(path) dict
    if self.path.isDirectory != 1
        throw "NERDTree.IllegalOperation Exception: Cannot perform oTreeNode.GetChild() on a file node"
    endif
    if stridx(a:path.GetPath(1), self.path.GetPath(1), 0) == -1
        return -1
    endif

    "do a binary search for the child 
    let a = 0
    let z = len(self.children)
    while a < z
        let mid = (a+z)/2
        let diff = a:path.CompareTo(self.children[mid].path, g:NERDTreeSortDirs)

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

"FUNCTION: oTreeNode.InitChildren {{{3 
"Assumes this node is a directory node.
"Removes all childen from this node and re-reads them
"
"Return: the number of child nodes read
function s:oTreeNode.InitChildren() dict
    if self.path.isDirectory != 1
        throw "NERDTree.IllegalOperation Exception: Cannot perform oTreeNode.InitChildren() on a file node"
    endif

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
                let newNode = s:oTreeNode.New(path, self)
            catch /^NERDTree.InvalidArguments/
                let invalidFilesFound = 1
            endtry
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
"
"Throws a NERDTree.IllegalOperation exception if called a filenode.
"
"Reads in all this nodes children
"
"Return: the number of child nodes read
function s:oTreeNode.Open() dict
    if self.path.isDirectory != 1
        throw "NERDTree.IllegalOperation Exception: Cannot perform oTreeNode.Open() on a file node"
    endif

    let self.isOpen = 1
    if self.children == []
        return self.InitChildren()
    else
        return 0
    endif
endfunction

"FUNCTION: oTreeNode.OpenRecursively {{{3 
"Assumes this node is a directory node.
"
function s:oTreeNode.OpenRecursively() dict
    if self.path.isDirectory != 1
        throw "NERDTree.IllegalOperation Exception: Cannot perform oTreeNode.OpenRecursively() on a file node"
    endif

    if self.path.Ignore() == 0
        let self.isOpen = 1
        if self.children == []
            call self.InitChildren()
        endif

        for i in self.children
            if i.path.isDirectory == 1
                call i.OpenRecursively() 
            endif
        endfor
    endif
endfunction

"FUNCTION: oTreeNode.Refresh {{{3 
"Assumes this node is a directory node.
function s:oTreeNode.Refresh() dict
    if self.path.isDirectory != 1
        throw "NERDTree.IllegalOperation Exception: Cannot perform oTreeNode.InitChildren() on a file node"
    endif

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
                    let newNode = s:oTreeNode.New(path, self)
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
        echo "Warning: some files could not be loaded into the NERD tree"
    endif

endfunction

"FUNCTION: oTreeNode.RemoveChild {{{3 
"
"Removes the given treenode from this nodes set of children
"
"Assumes this node is a directory node.
"
"Args:
"treenode: the node to remove
"
"Return:
"1 if the node is removed, 0 if not
function s:oTreeNode.RemoveChild(treenode) dict
    if self.path.isDirectory != 1
        throw "NERDTree.IllegalOperation Exception: Cannot perform oTreeNode.RemoveChild() on a file node"
    endif
    for i in range(0, len(self.children)-1)
        if self.children[i].Equals(a:treenode)
            call remove(self.children, i)
            return 1

        endif
    endfor

    return 0
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
"
"Throws a NERDTree.IllegalOperation exception if called a filenode.
"
"Opens this directory if it is closed and vice versa
function s:oTreeNode.ToggleOpen() dict
    if self.path.isDirectory != 1
        throw "NERDTree.IllegalOperation Exception: Cannot perform oTreeNode.ToggleOpen() on a file node"
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

"FUNCTION: oPath.ChangeToDir() {{{3 
function s:oPath.ChangeToDir() dict
    let dir = self.GetPath(1)
    if self.isDirectory == 0
        let dir = escape(self.GetPathTrunk(), s:escape_chars)
    endif

    try
        execute "cd " . dir
        echo "NERDTree: CWD is now: " . getcwd()
    catch
        throw "NERDTree.Path.Change exception: cannot change to " . dir
    endtry
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
function s:oPath.Create(fullpath) dict

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
function s:oPath.Delete() dict
    if self.isDirectory 

        let cmd = ""
        if s:running_windows
            "if we are runnnig windows then put quotes around the pathstring 
            let cmd = g:NERDRemoveDirCmd . '"' . self.GetPathForOS(0) . '"'
        else
            let cmd = g:NERDRemoveDirCmd . self.GetPathForOS(0)
        end
        let success = system(cmd)

        if v:shell_error != 0
            throw g:NERDRemoveDirCmd . self.GetPathForOS(0)
            throw "NERDTree.Path.Deletion Exception: Could not delete directory: '" . self.GetPathForOS(0) . "'"
        end
    else
        let success = delete(self.GetPath(0))
        if success != 0
            throw "NERDTree.Path.Deletion Exception: Could not delete file: '" . self.GetPath(0) . "'"
        endif
    endif
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
"Args:
"trailingSlash: 1 if a trailing slash is to be stuck on the end of the
"returned dir
"
"Return:
"string
function s:oPath.GetDir(trailingSlash) dict
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

"FUNCTION: oPath.GetDisplayString() {{{3 
"
"Returns a string that specifies how the path should be represented as a
"string
"
"Return:
"a string that can be used in the view to represent this path
function s:oPath.GetDisplayString() dict
    if self.isSymLink
        return self.GetLastPathComponent(1) . ' -> ' . self.symLinkDest
    elseif self.isReadOnly
        return self.GetLastPathComponent(1) . s:tree_RO_str
    else
        return self.GetLastPathComponent(1) 
    endif
endfunction
"FUNCTION: oPath.GetFile() {{{3 
"
"Returns the file component of this path. 
"
"Throws NERDTree.IllegalOperation exception if the node is a directory node 
function s:oPath.GetFile() dict
    if self.isDirectory == 0
        return self.GetLastPathComponent(0)
    else
        throw "NERDTree.IllegalOperation Exception: cannot get file component of a directory path"
    endif
endfunction

"FUNCTION: oPath.GetLastPathComponent(dirSlash) {{{3 
"
"Gets the last part of this path.   
"
"Args:
"dirSlash: if 1 then a trailing slash will be added to the returned value for
"directory nodes.
function s:oPath.GetLastPathComponent(dirSlash) dict
    if empty(self.pathSegments)
        return ''
    endif
    let toReturn = self.pathSegments[-1]
    if a:dirSlash && self.isDirectory
        let toReturn = toReturn . '/'
    endif
    return toReturn
endfunction

"FUNCTION: oPath.GetPath(esc) {{{3 
"
"Gets the actual string path that this obj represents.
"
"Args:
"esc: if 1 then all the tricky chars in the returned string will be escaped      
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

"FUNCTION: oPath.GetPathForOS() {{{3 
"
"Gets the string path for this path object that is appropriate for the OS.
"EG, in windows c:\foo\bar
"    in *nix  /foo/bar
"
"Args:
"esc: if 1 then all the tricky chars in the returned string will be escaped      
function s:oPath.GetPathForOS(esc) dict
    let lead = s:os_slash

    "if we are running windows then slap a drive letter on the front 
    if s:running_windows
        let lead = strpart(getcwd(), 0, 2) . s:os_slash
    end

    let toReturn = lead . join(self.pathSegments, s:os_slash)

    "if self.isDirectory && toReturn !~ escape(s:os_slash, '\/') . '$'
        "let toReturn  = toReturn . s:os_slash
    "endif

    if a:esc
        let toReturn = escape(toReturn, s:escape_chars)
    endif
    return toReturn
endfunction

"FUNCTION: oPath.GetPathTrunk() {{{3 
"Gets the path without the last segment on the end.
function s:oPath.GetPathTrunk() dict
    return '/' . join(self.pathSegments[0:-2], '/')
endfunction

"FUNCTION: oPath.Ignore() {{{3 
"returns true if this path should be ignored
function s:oPath.Ignore() dict
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
function s:oPath.Equals(path) dict
    return self.GetPath(1) == a:path.GetPath(1)
endfunction

"FUNCTION: oPath.New() {{{3 
"
"The Constructor for the Path object
"
"Throws NERDTree.InvalidArguments exception.
function s:oPath.New(fullpath) dict
    let newPath = copy(self)

    call newPath.ReadInfoFromDisk(a:fullpath)

    return newPath
endfunction

"FUNCTION: oPath.NewMinimal() {{{3 
function s:oPath.NewMinimal(fullpath) dict
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
"Throws NERDTree.InvalidArguments exception.
function s:oPath.ReadInfoFromDisk(fullpath) dict
    let fullpath = a:fullpath

    if s:running_windows
        let fullpath = s:oPath.WinToUnixPath(fullpath)
    endif

    "if the path is a dir, make sure its got a / on the end 
    "if isdirectory(fullpath) && fullpath !~ '\/$'
        "let fullpath = fullpath . '/'
    "endif

    let self.pathSegments = split(fullpath, '/')

    let self.isReadOnly = 0
    if isdirectory(fullpath)
        let self.isDirectory = 1
    elseif filereadable(fullpath)
        let self.isDirectory = 0
        let self.isReadOnly = filewritable(fullpath) == 0
    else
        throw "NERDTree.InvalidArguments Exception: Invalid path = " . fullpath
    endif

    "grab the last part of the path (minus the trailing slash) 
    let lastPathComponent = self.GetLastPathComponent(0)

    ""get the path to the new node with the parent dir fully resolved 
    let hardPath = resolve(self.GetPathTrunk()) . '/' . lastPathComponent

    ""if  the last part of the path is a symlink then flag it as such 
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
function s:oPath.Refresh() dict
    call self.ReadInfoFromDisk(self.GetPath(0))
endfunction

"FUNCTION: oPath.Rename() {{{3 
"
"Renames this node on the filesystem
"
"Assumes this path is a file
function s:oPath.Rename(newPath) dict
    if self.isDirectory
        throw "NERDTree.IllegalOperation Exception: cannot rename directories"
    endif

    if a:newPath == ''
        throw "NERDTree.InvalidArguments exception. Invalid newPath for renaming = ". a:newPath
    endif

    try
        let success =  rename(self.GetPath(0), escape(a:newPath, s:escape_chars))
        if success != 0
            throw "NERDTree.Path.Rename Exception: Could not rename: '" . self.GetPath(0) . "'"
        endif
        let self.pathSegments = split(a:newPath, '/')
    catch
        throw "NERDTree.Path.Rename exception. Could not rename from:" . self.GetPath(0) . ' to: ' . a:newPath
    endtry
endfunction

"FUNCTION: oPath.WinToUnixPath(pathstr){{{3
"Takes in a windows path and returns the unix equiv
"
"A class level method
"
"Args:
"pathstr: the windows path to convert
function s:oPath.WinToUnixPath(pathstr) dict
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

"FUNCTION: s:InitNerdTree(dir) {{{2 
"Initialized the NERD tree, where the root will be initialized with the given
"directory
"
"Arg:
"dir: the dir to init the root with
function s:InitNerdTree(dir)
    let dir = a:dir == '' ? expand('%:p:h') : a:dir
    let dir = resolve(dir)

    if !isdirectory(dir)
        echo "NERD_Tree: Error reading: " . dir
        return
    endif

    "if instructed to, then change the vim CWD to the dir the NERDTree is
    "inited in 
    if g:NERDTreeChDirMode != 0
        exec "cd " . dir
    endif

    let t:treeShowHelp = 0
    let t:NERDTreeIgnoreEnabled = 1

    if exists("t:currentRoot")
        if s:GetTreeWinNum() != -1
            call s:CloseTree()
        endif
        unlet t:currentRoot
    endif

    let path = s:oPath.New(dir)
    let t:currentRoot = s:oTreeNode.New(path, {})
    call t:currentRoot.Open()

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
function s:CloseTree()
    let winnr = s:GetTreeWinNum()
    if winnr == -1
        throw "NERDTree.view.CloseTree exception: no NERDTree is open"
    endif

    if winnr("$") != 1
        execute winnr . " wincmd w"
        close
        execute "wincmd p"
    else
        :q
    endif
endfunction

"FUNCTION: s:CreateTreeWin() {{{2 
"Inits the NERD tree window. ie. opens it, sizes it, sets all the local
"options etc
function s:CreateTreeWin()
    "create the nerd tree window 
    let splitLocation = g:NERDTreeWinPos ? "topleft " : "belowright "
    let splitMode = g:NERDTreeSplitVertical ? "vertical " : ""
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


        execute "syn match treeUp #". s:tree_up_dir_line ."#"
        syn match treeFlag #\[RO\]#
        syn match treeRO #[0-9a-zA-Z]\+.*\[RO\]# contains=treeFlag
        syn match treeOpenable #+\<#
        syn match treeOpenable #\~\<#
        syn match treeOpenable #\~\.#
        syn match treeOpenable #+\.#

        hi def link treePrt Normal
        hi def link treeHlp Special
        hi def link treeDir Directory
        hi def link treeUp Directory
        hi def link treeCWD Statement
        hi def link treeLnk Title
        hi def link treeOpenable Title
        hi def link treeFlag ignore
        hi def link treeRO WarningMsg
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
        let line = treeParts . a:curNode.GetDisplayString()

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

"FUNCTION: s:DumpHelp {{{2 
"prints out the quick help 
function s:DumpHelp()
    let old_h = @h
    if t:treeShowHelp == 1
        let @h=   "\" NERD tree quick help\n"
        let @h=@h."\" ==================================\n"
        let @h=@h."\" Mappings for opening file nodes:\n"
        let @h=@h."\" <ret>\n"
        let @h=@h."\" double-click\n"
        let @h=@h."\" o     = open selected file\n"
        let @h=@h."\" t     = open in a new tab\n"
        let @h=@h."\" T     = open in a new tab, stay in current tab\n"
        let @h=@h."\" middle-click\n"
        let @h=@h."\" <tab> = open in a new window\n"

        let @h=@h."\" \n\" ----------------------------------\n"
        let @h=@h."\" Mappings for directory nodes:\n"
        let @h=@h."\" <ret>\n"
        let @h=@h."\" double-click\n"
        let @h=@h."\" o     = expand/close selected directory\n"
        let @h=@h."\" O     = recursively open selected directory\n"
        let @h=@h."\" x     = close the current dir\n"
        let @h=@h."\" X     = close all children of current node\n"
        let @h=@h."\" middle-click\n"
        let @h=@h."\" e     = Open file explorer on current dir\n"
        let @h=@h."\" E     = Open file explorer in new window on current dir\n"

        let @h=@h."\" \n\" ----------------------------------\n"
        let @h=@h."\" Tree navigation mappings:\n"
        let @h=@h."\" p     = move cursor to parent directory\n"
        let @h=@h."\" s     = move cursor to next sibling node\n"
        let @h=@h."\" S     = move cursor to previous sibling node\n"

        let @h=@h."\" \n\" ----------------------------------\n"
        let @h=@h."\" Filesystem mappings:\n"
        let @h=@h."\" C     = change tree root to selected dir node\n"
        let @h=@h."\" cd    = change the CWD to selected node dir\n"
        let @h=@h."\" u     = move up a dir\n"
        let @h=@h."\" U     = move up a dir, leave old root open\n"
        let @h=@h."\" r     = refresh cursor dir\n"
        let @h=@h."\" R     = refresh current root\n"
        let @h=@h."\" m     = Show filesystem menu\n"

        let @h=@h."\" \n\" ----------------------------------\n"
        let @h=@h."\" Tree filtering mappings:\n"
        let @h=@h."\" H     = toggle show hidden (currently: " .  (g:NERDTreeShowHidden ? "on" : "off") . ")\n"
        let @h=@h."\" f     = toggle file filter (currently: " .  (t:NERDTreeIgnoreEnabled ? "on" : "off") . ")\n"
        let @h=@h."\" F     = toggle show files (currently: " .  (g:NERDTreeShowFiles ? "on" : "off") . ")\n"

        let @h=@h."\" \n\" ----------------------------------\n"
        let @h=@h."\" Other mappings:\n"
        let @h=@h."\" q     = Close the NERDTree window\n"
        let @h=@h."\" ?     = toggle help\n"
    else
        let @h="\" ? : toggle help\n"
    endif

    silent! put h

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
        return t:currentRoot.path
    endif

    " in case called from outside the tree
    if line !~ '^ *[|`]' || line =~ '^$'
        return {}
    endif

    if line == s:tree_up_dir_line
        return s:oPath.New( t:currentRoot.path.GetDir(0) )
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
        return t:currentRoot.FindNode(path)
    catch /.*/
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
    exec("silent " . splitMode." sp " . a:treenode.path.GetPath(0))

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

"FUNCTION: s:RenderView {{{2 
"The entry function for rendering the tree. Renders the root then calls
"s:DrawTree to draw the children of the root
"
"Args:
function s:RenderView()
    execute s:GetTreeWinNum() . "wincmd w"

    setlocal modifiable

    "remember the top line of the buffer and the current line so we can
    "restore the view exactly how it was
    let curLine = line(".")
    let curCol = col(".")
    let topLine = line("w0")

    "delete all lines in the buffer (being careful not to clobber a register)  
    let save_y = @"
    silent! normal ggdG
    let @" = save_y

    call s:DumpHelp()

    "delete the blank line before the help and add one after it 
    call setline(line(".")+1, " ")
    call cursor(line(".")+1, col("."))

    "add the 'up a dir' line 
    call setline(line(".")+1, s:tree_up_dir_line)
    call cursor(line(".")+1, col("."))

    "draw the header line  
    call setline(line(".")+1, t:currentRoot.path.GetPath(0))
    call cursor(line(".")+1, col("."))

    "draw the tree 
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
    let t:NERDTreeOldTopLine = line("w0")
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
function s:Toggle(dir)
    if exists("t:currentRoot")
        if s:GetTreeWinNum() == -1
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
function s:ActivateNode()
    if getline(".") == s:tree_up_dir_line
        return s:UpDir(0)
    endif
    let treenode = s:GetSelectedNode()
    if treenode == {} 
        echo "NERDTree: cannot open selected entry"
        return
    endif

    if treenode.path.isDirectory
        call treenode.ToggleOpen()
        call s:RenderView()
        call s:PutCursorOnNode(treenode)
    else
        let oldwin = winnr()
        wincmd p
        if oldwin == winnr() || (&modified && s:BufInWindows(winbufnr(winnr())) < 2)
            wincmd p
            call s:OpenFileNodeSplit(treenode)
        else
            exec ("edit " . treenode.path.GetPath(0))
        endif
    endif
endfunction

"FUNCTION: s:BindMappings() {{{2
function s:BindMappings()
    " set up mappings and commands for this buffer
    nnoremap <silent> <buffer> <cr> :call <SID>ActivateNode()<cr>
    nnoremap <silent> <buffer> o :call <SID>ActivateNode()<cr>
    nnoremap <silent> <buffer> <tab> :call <SID>OpenEntrySplit()<cr>
    nnoremap <silent> <buffer> <2-leftmouse> :call <SID>ActivateNode()<cr> 
    nnoremap <silent> <buffer> <middlerelease> :call <SID>HandleMiddleMouse()<cr>
    nnoremap <silent> <buffer> <leftrelease> <leftrelease>:call <SID>CheckForActivate()<cr>

    nnoremap <silent> <buffer> O :call <SID>OpenNodeRecursively()<cr>

    nnoremap <silent> <buffer> U :call <SID>UpDir(1)<cr>
    nnoremap <silent> <buffer> u :call <SID>UpDir(0)<cr>
    nnoremap <silent> <buffer> C :call <SID>ChRoot()<cr>

    nnoremap <silent> <buffer> cd :call <SID>ChCwd()<cr>

    nnoremap <silent> <buffer> q :NERDTreeToggle<cr>

    nnoremap <silent> <buffer> R :call <SID>RefreshRoot()<cr>
    nnoremap <silent> <buffer> r :call <SID>RefreshCurrent()<cr>

    nnoremap <silent> <buffer> ? :call <SID>DisplayHelp()<cr>
    nnoremap <silent> <buffer> H :call <SID>ToggleShowHidden()<cr>
    nnoremap <silent> <buffer> f :call <SID>ToggleIgnoreFilter()<cr>
    nnoremap <silent> <buffer> F :call <SID>ToggleShowFiles()<cr>

    nnoremap <silent> <buffer> x :call <SID>CloseCurrentDir()<cr>
    nnoremap <silent> <buffer> X :call <SID>CloseChildren()<cr>

    nnoremap <silent> <buffer> m :call <SID>ShowFileSystemMenu()<cr>

    nnoremap <silent> <buffer> p :call <SID>JumpToParent()<cr>
    nnoremap <silent> <buffer> s :call <SID>JumpToSibling(1)<cr>
    nnoremap <silent> <buffer> S :call <SID>JumpToSibling(0)<cr>

    nnoremap <silent> <buffer> t :call <SID>OpenEntryNewTab(0)<cr>
    nnoremap <silent> <buffer> T :call <SID>OpenEntryNewTab(1)<cr>

    nnoremap <silent> <buffer> e :call <SID>OpenExplorer(0)<cr>
    nnoremap <silent> <buffer> E :call <SID>OpenExplorer(1)<cr>
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

" FUNCTION: s:ChCwd() {{{2
function s:ChCwd() 
    let treenode = s:GetSelectedNode()
    if treenode == {} 
        echo "NERDTree: Select a node first"
        return
    endif

    try
        call treenode.path.ChangeToDir()
    catch
        echo "NERDTree: could not change cwd"
    endtry

endfunction

" FUNCTION: s:ChRoot() {{{2
" changes the current root to the selected one
function s:ChRoot() 
    let treenode = s:GetSelectedNode()
    if treenode == {} 
        echo "NERDTree: cannot change root node"
        return
    elseif treenode.path.isDirectory == 0
        echo "NERDTree: cannot change root node"
        return
    endif

    if treenode.isOpen == 0
        call treenode.Open()
    endif

    let t:currentRoot = treenode
    
    "change dir to the dir of the new root if instructed to 
    if g:NERDTreeChDirMode == 2
        exec "cd " . treenode.path.GetPath(0)
    endif


    call s:RenderView()
    call s:PutCursorOnNode(t:currentRoot)
endfunction

" FUNCTION: s:CloseChildren() {{{2
" closes all childnodes of the current node
function s:CloseChildren() 
    let currentNode = s:GetSelectedNode()
    if currentNode.path.isDirectory == 0
        let currentNode = currentNode.parent
    endif

    if empty(currentNode)
        echo "NERDTree: cannot close children"
    else
        call currentNode.CloseChildren()
        call s:RenderView()
        call s:PutCursorOnNode(currentNode)
    endif


endfunction
" FUNCTION: s:CloseCurrentDir() {{{2
" closes the parent dir of the current node
function s:CloseCurrentDir() 
    let treenode = s:GetSelectedNode()
    let parent = treenode.parent
    if parent.path.GetPath(0) == t:currentRoot.path.GetPath(0)
        echo "NERDTree: cannot close tree root"
    else
        call treenode.parent.Close()
        call s:RenderView()
        call s:PutCursorOnNode(treenode.parent)
    endif
endfunction

" FUNCTION: s:DeleteNode() {{{2
" if the current node is a file, pops up a dialog giving the user the option
" to delete it
function s:DeleteNode() 
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
                         \ "|" . currentNode.path.GetPathForOS(0) . ": ")
        let confirmed = choice == 'yes'
    else
        echo "|NERDTree Node Deletor\n" .
                         \ "|==========================================================\n". 
                         \ "|Are you sure you wish to delete the node:\n" . 
                         \ "|" . currentNode.path.GetPathForOS(0) . " (yN):"
        let choice = nr2char(getchar())
        let confirmed = choice == 'y'
    end


    if confirmed
        "try
            call currentNode.path.Delete()
            call currentNode.parent.RemoveChild(currentNode)
            call s:RenderView()
            redraw
        "catch
            "echo "NERDTree: Could not remove node" 
        "endtry
    else
        echo "NERDTree: delete aborted" 
    endif

endfunction

" FUNCTION: s:DisplayHelp() {{{2
" toggles the help display
function s:DisplayHelp() 
    let t:treeShowHelp = t:treeShowHelp ? 0 : 1
    call s:RenderView()
endfunction

" FUNCTION: s:HandleMiddleMouse() {{{2
function s:HandleMiddleMouse() 
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
function s:InsertNewNode() 
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
                          \ "|", curDirNode.path.GetPath(0))
    
    if newNodeName == ''
        echo "NERDTree: Node Creation Aborted."
        return
    endif

    try
        let newPath = s:oPath.Create(newNodeName)

        let parentNode = t:currentRoot.FindNode(s:oPath.New(newPath.GetPathTrunk()))

        if parentNode.isOpen == 1 || !empty(parentNode.children) 
            let newNode = s:oTreeNode.New(newPath, parentNode)
            call parentNode.SortChildren()
            call s:RenderView()
        endif
    catch /.*/
        echo "NERDTree: Node Not Created."
    endtry
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
        exec "tabedit " . treenode.path.GetPath(0)
        if a:stayCurrentTab
            exec "tabnext " . curTabNr
        endif
    else
        echo "NERDTree: cannot open selected entry"
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
        echo "NERDTree: cannot open selected entry"
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
                exec ("edit " . treenode.path.GetPath(0))
            endif
        endif
    else
        echo "NERDTree: cannot open explorer on selected node"
    endif
    
endfunction

" FUNCTION: s:OpenNodeRecursively() {{{2
function! s:OpenNodeRecursively() 
    let treenode = s:GetSelectedNode()
    if treenode != {}
        if treenode.path.isDirectory == 1
            echo "Recursively opening node. This could take a while..."
            call treenode.OpenRecursively()
            call s:RenderView()
            redraw
            echo "Recursively opening node. This could take a while... FINISHED"
        else
            echo "NERDTree: Select a directory node" 
        endif

    else
        echo "NERDTree: Select a directory node" 
    endif
    
endfunction

" FUNCTION: s:RefreshRoot() {{{2
" Reloads the current root. All nodes below this will be lost and the root dir
" will be reloaded.
function! s:RefreshRoot() 
    echo "NERDTree: Refreshing the root node. This could take a while..."
    call t:currentRoot.Refresh()
    call s:RenderView()
    redraw
    echo "NERDTree: Refreshing the root node. This could take a while... FINISHED"
endfunction

" FUNCTION: s:RefreshCurrent() {{{2
" refreshes the root for the current node
function! s:RefreshCurrent() 
    let treenode = s:GetSelectedNode()
    if treenode == {} 
        echo "NERDTree: cannot refresh selected dir"
        return
    endif

    let curDir = treenode.path.GetDir(1)
    let parentNode = t:currentRoot.FindNode( s:oPath.New(curDir) )
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
" allows the user to rename the current file node
function! s:RenameCurrent() 
    let curNode = s:GetSelectedNode()
    if curNode == {}
        echo "NERDTree: Put the cursor on a file node first" 
        return
    endif

    if curNode.path.isDirectory == 1
        echo "NERDTree: Renaming directories not supported"
        return
    endif

    let newNodePath = input("|NERDTree Node Renamer\n" .
                          \ "|==========================================================\n". 
                          \ "|Enter the new path for the file:                          \n" . 
                          \ "|", curNode.path.GetPath(0))
    
    if newNodePath == ''
        echo "NERDTree: Node Renaming Aborted."
        return
    endif

    let newNodePath = substitute(newNodePath, '\/$', '', '')

    try
        call curNode.path.Rename(newNodePath)

        call curNode.parent.RemoveChild(curNode)

        let parentPath = s:oPath.New(curNode.path.GetDir(0))
        let newParent = t:currentRoot.FindNode(parentPath)

        if newParent != {}
            let newNode = s:oTreeNode.New(curNode.path, newParent)
            call newParent.SortChildren()
        endif
        call s:RenderView()
    catch /.*/
        echo "NERDTree: Node Not Renamed."
    endtry
endfunction

" FUNCTION: s:ShowFileSystemMenu() {{{2
function s:ShowFileSystemMenu() 
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
function s:ToggleIgnoreFilter() 
    let t:NERDTreeIgnoreEnabled = !t:NERDTreeIgnoreEnabled
    call s:RenderView()
endfunction

" FUNCTION: s:ToggleShowFiles() {{{2
" toggles the display of hidden files
function s:ToggleShowFiles() 
    let g:NERDTreeShowFiles = !g:NERDTreeShowFiles

    let currentDir = s:GetSelectedNode()
    if currentDir != {} && currentDir.Equals(t:currentRoot) == 0
        if currentDir.path.isDirectory == 0
            let currentDir = currentDir.parent
        endif
    endif

    call s:RenderView()

    if currentDir != {}
        call s:PutCursorOnNode(currentDir)
        normal zz
    endif
endfunction

" FUNCTION: s:ToggleShowHidden() {{{2
" toggles the display of hidden files
function s:ToggleShowHidden() 
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

    let cwd = t:currentRoot.path.GetPath(0)
    if cwd == "/" || cwd =~ '^[^/]..$'
        echo "NERDTree: already at top dir"
    else
        if !a:keepState
            call t:currentRoot.Close()
        endif

        let oldRoot = t:currentRoot

        if empty(t:currentRoot.parent)
            let path = s:oPath.New(t:currentRoot.path.GetPathTrunk())
            let newRoot = s:oTreeNode.New(path, {})
            call newRoot.Open()
            call newRoot.TransplantChild(t:currentRoot)
            let t:currentRoot = newRoot
        else
            let t:currentRoot = t:currentRoot.parent

        endif

        call s:RenderView()
        call s:PutCursorOnNode(oldRoot)
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
*NERD_tree.txt*   A plugin for navigating the filesystem        #version#


                           NERD_TREE REFERENCE MANUAL~





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
    6.Credits.................................|NERD_tree-credits|

==============================================================================
                                                                   *NERD_tree*
1. Intro {{{2 ~

What is this "NERD_tree"??

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
    * Many mappings are provided to manipulate the tree:
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

When the cursor is in the NERD tree window the following mappings may be used:

Key         Description~

q           Closes the NERDTree window
<ret>,
o           If the cursor is on a file, this file is opened in the previous
            window. If the cursor is on a directory, the directory node is
            expanded in the tree.
O           Applies to dirs. Recursively opens the selected directory. This
            could take a while to complete so be prepared to go grab a cup of
            tea. Only opens dirs that aren't filtered out by file filters or the
            hidden files filter.
<tab>       Only applies to files. Opens the selected file in a new split
            window. 
t           Opens the selected node in a new tab. If a dir is selected then an
            explorer for that dir will be opened.
T           Same as 't' but keeps the focus on the current tab
x           Closes the directory that the cursor is inside.
X           Closes all children (recursively) of the current node
C           Only applies to directories. Changes the current root of the NERD
            tree to the selected directory.
cd          Changes the current working directory to the directory of the
            selected node.
u           Change the root of the tree up one directory.
U           Same as 'u' except the old root is left open.
r           Recursively refreshes the directory that the cursor is currently inside. If
            the cursor is on a directory node, this directory is refreshed.
R           Recursively refreshes the current root of the tree... this could
            take a while for large trees.
p           Moves the cursor to parent directory of the directory it is
            currently inside.
s           Moves the cursor to next sibling of the current node.
S           Moves the cursor to previous sibling of the current node.
H           Toggles whether hidden files are shown or not.
f           Toggles whether the file filters (as specified in the
            |NERDTreeIgnore| option) are used.
F           Toggles the |NERDTreeShowFiles| option, causing files to be hidden
            if they are currently displayed and vice versa.   
e           If the cursor is on a directory node, this directory is opened in
            a file explorer. If it is on a file, the file-node's parent directory is
            opened in a file explorer. The file explorer is always opened in
            the previous window.
E           Like 'e' except the file explorer is opened in a new split window.
m           Displays the filesystem menu see |NERD_tree-filesys-menu|.
?           Toggles the display of the quick help at the top of the tree.

The following mouse mappings are available:

Key             Description~

double click    Has the same effect as pressing 'o'

middle click    Has a different effect when used on a file and a dir:
                For files it is the same as '<tab>', for directories it is the
                same as 'e'.


Additionally, directories can be opened and closed by clicking the '+' and '~'
symbols on their left.

------------------------------------------------------------------------------
                                                      *NERD_tree-filesys-menu*
2.3. The filesystem menu {{{3 ~

The purpose of the filesystem menu is to allow you to perform basic filesystem
operations quickly from the NERD tree rather than the console.  

The filesystem menu currently supports the following operations:

Insertion of new nodes into the tree. This corresponds to adding files or
directories to the filesystem. When this action is chosen, the script prompts
you for a name for the new node. If you type a string ending with a '/'
character, a directory is created, else a file is created. The new node is
inserted as a child of the current node, or the current node's parent (if the
current node is a file, not a dir)

Deletion of file and directories.

Renaming of file nodes.  

To access the filesystem menu, put the cursor on a node and press 'm'.

==============================================================================
                                                     *NERD_tree-customisation*
3. Customisation {{{2 ~


------------------------------------------------------------------------------
                                                      *NERD_tree-cust-summary*
3.1. Customisation summary {{{3 ~

The script provides the following options that can customise the behaviour the
NERD tree. These options should be set in your vimrc.

|loaded_nerd_tree|              Turns off the script

|NERDTreeChDirMode|             Tells the NERD tree if/when it should change
                                vim's current working directory 

|NERDTreeIgnore|                Tells the NERD tree which files to ignore.

|NERDTreeShowFiles|             Tells the NERD tree whether to display files
                                in the tree on startup.

|NERDTreeShowHidden|            Tells the NERD tree whether to display hidden
                                files on startup.

|NERDTreeSortDirs|              Tells the NERD tree how to position the
                                directory/file nodes within their parent node. 


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
                                                           *NERDTreeChDirMode*                
Use this option to tell the script when (if at all) to change the current
working directory (CWD) for vim.

This option takes one of 3 values: >
    let NERDTreeChDirMode = 0
    let NERDTreeChDirMode = 1
    let NERDTreeChDirMode = 2
<
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

Defaults to 1.

------------------------------------------------------------------------------
                                                              *NERDTreeIgnore*                
This option is used to specify which files the NERD tree should ignore.  It
must be a list of regular expressions. When the NERD tree is rendered, any
files/dirs that match any of the regex's in NERDTreeIgnore wont be displayed. 

For example if you put the following line in your
vimrc: >
    let NERDTreeIgnore=['.vim$', '\~$']
<
then all files ending in .vim or ~ will be ignored. 

Note: to tell the NERD tree not to ignore any files you must use the following
line: >
    let NERDTreeIgnore=[]
<

The file filters can be turned on and off dynamically with the f mapping.

Defaults to ['\~$'].

------------------------------------------------------------------------------
                                                           *NERDTreeShowFiles*            
This option can take two values: >
    let NERDTreeShowFiles=0
    let NERDTreeShowFiles=1
<
If this option is set to 1 then files are displayed in the NERD tree. If it is
set to 0 then only directories are displayed.

This option can be toggles dynamically with the F mapping and is useful for
drastically shrinking the tree when you are navigating to a different part of
the tree.

This option can be used in conjunction with the e, middle-click and E mappings
to make the NERD tree function similar to windows explorer.

Defaults to 1.

------------------------------------------------------------------------------
                                                          *NERDTreeShowHidden*            
This option tells vim whether to display hidden files by default. This option
can be dynamically toggled with the D mapping see |NERD_tree_mappings|.
Use one of the follow lines to set this option: >
    let NERDTreeShowHidden=0
    let NERDTreeShowHidden=1
<
                                                       
Defaults to 0.

------------------------------------------------------------------------------
                                                            *NERDTreeSortDirs*
This option is used to tell the NERD tree how to position file nodes and
directory nodes within their parent. This option can take 3 values: >
    let NERDTreeSortDirs=0
    let NERDTreeSortDirs=1
    let NERDTreeSortDirs=-1
<
If NERDTreeSortDirs is set to 0 then no distinction is made between file nodes
and directory nodes and they are sorted alphabetically.
If NERDTreeSortDirs is set to 1 then directories will appear above the files. 
If NERDTreeSortDirs is set to -1 then directories will appear below the files. 

Defaults to 0.

------------------------------------------------------------------------------
                                                       *NERDTreeSplitVertical*
This option, along with |NERDTreeWinPos|, is used to determine where the NERD
tree window appears. This option can take 2 values: >
    let NERDTreeSplitVertical=0
    let NERDTreeSplitVertical=1
<
If it is set to 1 then the NERD tree window will appear on either the left or
right side of the screen (depending on the |NERDTreeWinPos| option).

If it set to 0 then the NERD tree window will appear at the top of the screen.

Defaults to 1.

------------------------------------------------------------------------------
                                                              *NERDTreeWinPos*
This option works in conjunction with the |NERDTreeSplitVertical| option to
determine where NERD tree window is placed on the screen.

NERDTreeWinPos can take one of two values: >
    let NERDTreeWinPos=0
    let NERDTreeWinPos=1
<
If the option is set to 1 then the NERD tree will appear on the left or top of
the screen (depending on the value of |NERDTreeSplitVertical|). If set to 0,
the window will appear on the right or bottom of the screen. 

This option is makes it possible to use two different explorer type
plugins simultaneously. For example, you could have the taglist plugin on the
left of the window and the NERD tree on the right.

Defaults to 1.

------------------------------------------------------------------------------
                                                             *NERDTreeWinSize*               
This option is used to change the size of the NERD tree when it is loaded.
To use this option, stick the following line in your vimrc: >
    let NERDTreeWinSize=[New Win Size]
<

Defaults to 30.

==============================================================================
                                                              *NERD_tree-todo*
4. TODO list {{{2 ~

Window manager integration?

make more extensive filesystem operations available

make the mappings customisable?

dynamic hiding of tree content (eg, if you dont want to see a particular
directory for the rest of the current vim session, you can hide it with a
mapping)

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
Don't be shy --- the worst he can do is slaughter you and stuff you in the
fridge for later.    

==============================================================================
                                                           *NERD_tree-credits*
6. Credits {{{2 ~

Thanks to Tim Carey-Smith for testing/using the NERD tree from the first
pre-beta version, for his many suggestions and for his constant stream of bug
complaints.

Thanks to Vigil for trying it out before the first release :) and suggesting
that mappings to open files in new tabs should be implemented.

Thanks to Nick Brettell for testing, fixing my spelling and suggesting i put a
    .. (up a directory)
line in the gui.

Thanks to Thomas Scott Urban the author of the vtreeexplorer plugin whose gui
code i borrowed from.

Thanks to Terrance Cohen for pointing out a bug where the script was changing
vims CWD all over the show.

Thanks to Yegappan Lakshmanan (author of Taglist and other orgasmically
wonderful plugins) for telling me how to fix a bug that was causing vim to go
into visual mode everytime you double clicked a node :)

Thanks to Jason Mills for sending me a fix that allows windows paths to use
forward slashes as well as backward.

=== END_DOC
" vim: set ts=4 sw=4 foldmethod=marker foldmarker={{{,}}} foldlevel=2:
