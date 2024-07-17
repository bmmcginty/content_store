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
puts cmd
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

def initialize(name)
parent=Path["data/site"].expand
dn=parent.join(name).expand
if ! dn.parents.includes?(parent)
raise ContentStoreBoundaryError.new(dn,parent)
end
@path=dn
end

def open(item)
p=@path.join(Path[item]).normalize
if ! p.parents.includes?(@path)
raise ContentStoreBoundaryError.new(p,@path)
end
RepoItem.new p, @ext
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

def initialize(path, @ext)
@path=Path[path.to_s+"."+@ext]
@ls.concat list_compressed
end

def temp_dir
Path[@path.to_s+".tmpdir"]
end

def temp_file
Path[@path.to_s+".tmpfile"]
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

def open(name)
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
open(name) do |fh|
fh << content
end
end # def

def close
if @added.size>0
compress
end
if File.exists?(temp_dir)
FileUtils.rm_r(temp_dir)
end
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

def compress
if File.exists?(@path)
cmd=["bsdtar", "-x", "-f", @path.to_s, "-C", temp_dir.to_s, "--keep-old-files"]
run cmd
end
cmd=["bsdtar", "-c", "--"+@ext.split(".")[-1], "-f", temp_file.to_s, "-C", temp_dir.to_s, "."]
run cmd
File.rename temp_file, @path
end # def

end # class

