
import re

file_path = r'c:\Users\manso\nawafeth\mobile\lib\screens\interactive_screen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace .withOpacity(x) with .withValues(alpha: x)
new_content = re.sub(r'\.withOpacity\(([^)]+)\)', r'.withValues(alpha: \1)', content)

# Fix (__, __) to (context, _)
new_content = new_content.replace('(_, __)', '(context, _)')
new_content = new_content.replace('(_,___)', '(context, error, stackTrace)') 

# Fix (_,__)
new_content = new_content.replace('(_,__) =>', '(context, _) =>')


with open(file_path, 'w', encoding='utf-8') as f:
    f.write(new_content)
    
print("Fixed deprecations")
