import os, strutils

proc getBranchFromString(str: string): string =
  return str.split("/")[^1]

proc getCurrentBranch*(current_dir: string): string =
  if (current_dir / ".git/HEAD").fileExists():
    let file = readFile(current_dir / ".git/HEAD")
    return getBranchFromString(file)
  else:
    return "NONE"