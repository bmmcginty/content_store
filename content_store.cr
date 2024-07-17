require "file_utils"

class ContentStoreError < Exception
def inspect
to_s
end

def to_s(io : IO)
io << to_s
end

def inspect(io : IO)
io << to_s
end

end


class ContentStoreNotClosedError < ContentStoreError
@path : Path

def initialize(@path)
end

def to_s
"repo with path #{@path} was not closed before cleanup; temp files explicitly not deleted to allow for examination"
end

end


class ContentStoreBoundaryError < ContentStoreError
@path : Path
@parent : Path

def initialize(@path, @parent)
end

def to_s
"path #{@path} not inside #{@parent}"
end

end


class ContentStoreNotFoundError < ContentStoreError
@path : Path
@parent : Path

def initialize(@path, @parent)
end

def to_s
"path #{@path} not found in #{@parent}"
end

end


def run(cmd : Array(String), output : Bool = true)
puts cmd.join(" ")
sp=Process.new(
command: cmd[0],
args: cmd[1..-1],
output: (
output ? Process::Redirect::Pipe : Process::Redirect::Close))
yield sp.output?
ret=sp.wait
if ret.exit_code!=0
raise Exception.new("rc #{ret.exit_code} for cmd #{cmd}")
end
end

def run(cmd)
run(cmd,output: false) do |o|
end
end

class Repo
@path : Path
@ext="tar.zstd"
@created=false

def initialize(name)
parent=Path["data/site"].expand
dn=parent.join(name).expand
if ! dn.parents.includes?(parent)
raise ContentStoreBoundaryError.new(dn,parent)
end
@path=dn
end

def open(item, ensure_clean=false)
p=@path.join(Path[item]).normalize
if ! p.parents.includes?(@path)
raise ContentStoreBoundaryError.new(p,@path)
end
if ! @created
Dir.mkdir_p @path
@created=true
end
RepoItem.new path: p, ext: @ext, ensure_clean: ensure_clean
end # def

def close
# maybe make sure no temp dirs exist?
end

end # class


class RepoItem
@path : Path
@ls = [] of Path
@added = [] of Path
@ext : String
@closed=false

# if you set ensure_clean to true,
# and you don't call #close,
# particularly if you encounter errors while the repo is open,
# you will lose all content from your last opening of the archive upon a reopen
# Basically, use ensure_clean only when doing content verification/exports.
def initialize(path, @ext, ensure_clean : Bool)
@path=Path[path.to_s+"."+@ext]
@ls.concat list_compressed
if ensure_clean
if File.exists?(temp_dir)
FileUtils.rm_r(temp_dir)
end
end
if File.exists?(temp_file)
FileUtils.rm_r(temp_file)
end
end

# convert a directory to an archive
# only convert if directory exists and archive does not exist
# (we do not want double-conversions by accident)
def convert(old = nil) : Bool
old = old ? old : @path.to_s.gsub(/.#{@ext}$/,"")
if File.exists?(old) && ! File.exists?(@path)
compress old
true
else
false
end
end

def temp_dir
ret=Path[@path.to_s+".tmpdir"]
ret
end

def temp_file
ret=Path[@path.to_s+".tmpfile"]
ret
end

def list
(@ls+@added).map &.to_s
end

def list_compressed
if ! File.exists?(@path)
return [] of Path
end # if
ret=[] of Path
cmd_list do |i|
next if i.ends_with?("/")
p=Path[i].normalize
ret << p
end
ret
end # def

def exists?(path)
pn=Path[path].normalize
(@ls.includes?(pn) ||
@added.includes?(pn))
end # def

def write(name)
pn=Path[temp_dir].join(name).normalize
if ! pn.parents.includes?(temp_dir)
raise ContentStoreBoundaryError.new(pn,temp_dir)
end
p=pn.to_s
Dir.mkdir_p temp_dir
begin
File.open(p+".tmp","w") do |fh|
yield fh
end # fh
File.rename(p+".tmp",p)
@added << Path[name].normalize
rescue e
File.delete p+".tmp"
raise e
end
end # def

def read(name)
t=nil
read name do |io|
t=io.gets_to_end
end
t.not_nil!
end

def read(name)
p=Path[name].normalize
if @added.includes?(p)
File.open(temp_dir.join(p), "r") do |io|
yield io
end
elsif @ls.includes?(p)
cmd=["bsdtar", "-x", "-f", @path.to_s, "--to-stdout", p.to_s]
run(cmd) do |io|
yield io.not_nil!
end
else
raise ContentStoreNotFoundError.new(p,@path)
end
end

def write(name,content)
write(name) do |fh|
fh << content
end
end # def

def finalize
if ! @closed
#puts "failed to close #{@path} before freeing"
end
end

def close
if @added.size>0
combine
end
if File.exists?(temp_dir)
FileUtils.rm_r(temp_dir)
end
@closed=true
end

def cmd_list
t=["bsdtar", "-t", "--"+@ext.split(".")[-1], "-f", @path.to_s]
run t do |output|
output=output.not_nil!
output.each_line do |l|
yield l.strip
end
end
end

def decompress(dest)
cmd=["bsdtar", "-x", "-f", @path.to_s, "-C", dest.to_s, "--keep-old-files"]
run cmd
end

def compress(src)
Dir.mkdir_p @path.parent
cmd=["bsdtar", "-c", "--"+@ext.split(".")[-1], "--strip-components", "1", "-f", temp_file.to_s, "-C", src.to_s, "."]
run cmd
File.rename temp_file, @path
end # def

# by default, extract existing archive to directory and recompress with new contents
def combine
if File.exists?(@path)
decompress dest: temp_dir
end
compress temp_dir
end

end # class


class ContentStore
def self.repo(name)
repo=Repo.new name
yield repo
repo.close
end

def self.open(path)
parts=path.split("/",2)
repo=Repo.new parts[0]
item=repo.open parts[1]
yield item
item.close
repo.close
end

end

