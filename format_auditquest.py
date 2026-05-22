import re

with open("auditquest.md", "r") as f:
    text = f.read()

# Remove YES and NO lines with any trailing spaces
text = re.sub(r'^[ \t]*YES[ \t]*\n', '', text, flags=re.MULTILINE)
text = re.sub(r'^[ \t]*NO[ \t]*\n', '', text, flags=re.MULTILINE)
text = re.sub(r'^[ \t]*YES[ \t]*$', '', text, flags=re.MULTILINE)
text = re.sub(r'^[ \t]*NO[ \t]*$', '', text, flags=re.MULTILINE)

# Reduce multiple newlines to max 2
text = re.sub(r'\n{3,}', '\n\n', text)

lines = text.split('\n')
new_lines = []

for i, line in enumerate(lines):
    # Make questions bold if they end with '?' and aren't already formatted
    stripped = line.strip()
    if stripped.endswith('?') and not stripped.startswith('#') and not stripped.startswith('*') and not stripped.startswith('>'):
        line = f"### {stripped}"
        
    new_lines.append(line)

final_text = '\n'.join(new_lines)

# Add a section for auditee instructions on unanswered questions
final_text = re.sub(
    r'### Were the learners able to answer all the questions correctly\?',
    '### Were the learners able to answer all the questions correctly?\n\n*Note for Auditee: Answer clearly, stay confident, and if asked something outside your immediate knowledge, refer to how you would find the answer in AWS documentation. Your prepared answers cover the bulk of the expected questions.*\n',
    final_text
)

final_text = re.sub(
    r'### Did the learners demonstrate a thorough understanding of the concepts and technologies used in the project\?',
    '### Did the learners demonstrate a thorough understanding of the concepts and technologies used in the project?\n\n*Note for Auditee: Demonstrate this by walking the auditor through the Terraform code and Postman requests naturally. Use proper terminology (e.g., "ECS Tasks" instead of just "containers", "JWT" instead of "token").*\n',
    final_text
)

final_text = re.sub(
    r'### Were the learners able to communicate effectively and justify their decisions\?',
    '### Were the learners able to communicate effectively and justify their decisions?\n\n*Note for Auditee: Keep explanations structured: State the decision, explain the "Why" (cost, scalability, simplicity), and point to the specific implementation (e.g., "We chose ECS over EKS because... as seen in ecs.tf").*\n',
    final_text
)

final_text = re.sub(
    r'### Could the learners critically evaluate their solution and consider alternative strategies\?',
    '### Could the learners critically evaluate their solution and consider alternative strategies?\n\n*Note for Auditee: You have a "Challenges" and "Future Improvements" section ready. Use it to show you know your system\'s limits and how to improve it (e.g., moving from EFS Postgres to RDS).*',
    final_text
)


with open("auditquest.md", "w") as f:
    f.write(final_text)
