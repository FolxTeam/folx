import os, options

proc gitBranch*(current_dir: string): Option[string] =
  if (current_dir / ".git/HEAD").fileExists():
    some readFile(current_dir / ".git/HEAD").splitPath.tail
  else:
    none string
