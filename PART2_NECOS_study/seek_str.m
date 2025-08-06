function [ind] = seek_str(s, c)
ind = [];
lc = length(c);
for i = 1:length(s)-lc
  if s(i:i+lc-1) == c
    ind = [ind i];
  end
end


