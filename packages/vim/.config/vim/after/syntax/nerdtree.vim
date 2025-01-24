" This file adds some customization to the syntax highlighting in NERDTree.
" Requirements:
"  * Vim must be compiled with the +conceal feature turned on.
"  * The file must be saved here: ~/.vim/after/syntax/nerdtree.vim

if !has("conceal")
    finish
endif

let s:dirArrows = escape(g:NERDTreeDirArrowCollapsible, '~]\-').escape(g:NERDTreeDirArrowExpandable, '~]\-')

syntax clear NERDTreeOpenable
syntax clear NERDTreeClosable

" ----------------------------------------------------------------------------
" This statement changes the indentation of NERDTree to appear as 1 space per
" level instead of the normal 2 spaces.
exec 'syntax match CompressSpaces #['.s:dirArrows.' ]\zs \ze.*' . g:NERDTreeNodeDelimiter . '# containedin=ALL conceal'