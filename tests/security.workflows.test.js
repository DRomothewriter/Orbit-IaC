import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const ROOT = path.resolve(__dirname, '..');

function repoPath(...segments) {
  return path.join(ROOT, ...segments);
}

function fileExists(...segments) {
  return fs.existsSync(repoPath(...segments));
}

function readRepoFile(...segments) {
  const fullPath = repoPath(...segments);
  assert.ok(fs.existsSync(fullPath), `Expected file to exist: ${segments.join('/')}`);
  return fs.readFileSync(fullPath, 'utf8');
}

function readJson(...segments) {
  const raw = readRepoFile(...segments);
  try {
    return JSON.parse(raw);
  } catch (err) {
    assert.fail(`Invalid JSON in ${segments.join('/')}: ${err.message}`);
  }
}

function assertMatchesAll(content, patterns, contextLabel) {
  for (const pattern of patterns) {
    if (pattern instanceof RegExp) {
      assert.match(content, pattern, `${contextLabel}: expected to match ${pattern}`);
    } else {
      assert.ok(
        content.includes(pattern),
        `${contextLabel}: expected to contain "${pattern}"`
      );
    }
  }
}

function extractRequiredCheckContexts(ruleset) {
  const rules = Array.isArray(ruleset.rules) ? ruleset.rules : [];
  const statusRule = rules.find((r) => r.type === 'required_status_checks');
  assert.ok(statusRule, 'Expected ruleset to contain a required_status_checks rule');
  const checks = statusRule.parameters?.required_status_checks || [];
  return checks.map((c) => c.context);
}

describe('1. Consolidation & Branch Hygiene', () => {
  it('removes legacy .github/workflows/validate-pr-source.yml after consolidation into security-main.yml', () => {
    assert.equal(
      fileExists('.github', 'workflows', 'validate-pr-source.yml'),
      false,
      '.github/workflows/validate-pr-source.yml must NOT exist (consolidated into security-main.yml)'
    );
  });
});

describe('2. Workflow 1: .github/workflows/ci-dev.yml', () => {
  it('triggers on pull_request targeting dev (opened, synchronize, reopened) with least-privilege permissions', () => {
    const content = readRepoFile('.github', 'workflows', 'ci-dev.yml');

    assertMatchesAll(
      content,
      [
        /on:\s*[\s\S]*pull_request:/,
        /branches:\s*[\s\S]*-\s*['"]?dev['"]?/,
        /opened/,
        /synchronize/,
        /reopened/,
        /permissions:/,
      ],
      'ci-dev.yml triggers & permissions'
    );

    assert.doesNotMatch(content, /permissions:\s*write-all/, 'ci-dev.yml must not use write-all');
    assert.doesNotMatch(content, /id-token:\s*write/, 'ci-dev.yml must not request id-token: write');
  });

  it('defines Validate Branch, State Guard & Terraform job with branch rules, state guard, and terraform checks', () => {
    const content = readRepoFile('.github', 'workflows', 'ci-dev.yml');

    assertMatchesAll(
      content,
      [
        /name:\s*['"]?Validate Branch, State Guard & Terraform['"]?/,
        /main/,
        /feature\/\|bug\/\|fix\/\|docs\/\|chore\/\|refactor\/\|test\/\|dependabot\//,
        /git ls-files/,
        /tfstate/,
        /terraform\.tfvars/,
        /example/,
        /terraform fmt -check -recursive/,
        /terraform init -backend=false/,
        /terraform validate/,
      ],
      'ci-dev.yml Validate Branch, State Guard & Terraform job'
    );
  });

  it('defines Secret Scanning (TruffleHog) job with --only-verified and artifact upload', () => {
    const content = readRepoFile('.github', 'workflows', 'ci-dev.yml');

    assertMatchesAll(
      content,
      [
        /name:\s*['"]?Secret Scanning \(TruffleHog\)['"]?/,
        /trufflesecurity\/trufflehog/,
        /--only-verified/,
        /actions\/upload-artifact/,
      ],
      'ci-dev.yml TruffleHog job'
    );
  });

  it('defines IaC Lint & Security (TFLint & Trivy) job with TFLint, Trivy, SARIF upload, and 14-day artifact retention', () => {
    const content = readRepoFile('.github', 'workflows', 'ci-dev.yml');

    assertMatchesAll(
      content,
      [
        /name:\s*['"]?IaC Lint & Security \(TFLint & Trivy\)['"]?/,
        /terraform-linters\/setup-tflint/,
        /tflint/,
        /HIGH,CRITICAL/,
        /docker\/docker-compose\.prod\.yml/,
        /docker\/nginx\//,
        /github\/codeql-action\/upload-sarif@v3/,
        /actions\/upload-artifact/,
        /name:\s*['"]?dev-iac-security-reports['"]?/,
        /retention-days:\s*14/,
      ],
      'ci-dev.yml TFLint & Trivy job'
    );
  });
});

describe('3. Workflow 2: .github/workflows/security-main.yml', () => {
  it('triggers on pull_request to main, push to main, and workflow_dispatch, and NEVER runs terraform apply', () => {
    const content = readRepoFile('.github', 'workflows', 'security-main.yml');

    assertMatchesAll(
      content,
      [
        /pull_request:/,
        /push:/,
        /branches:\s*[\s\S]*-\s*['"]?main['"]?/,
        /workflow_dispatch:/,
      ],
      'security-main.yml triggers'
    );

    assert.doesNotMatch(
      content,
      /\bterraform\s+apply\b/,
      'security-main.yml must NEVER execute terraform apply'
    );
  });

  it('defines Verify PR originates from dev job rejecting github.head_ref != dev', () => {
    const content = readRepoFile('.github', 'workflows', 'security-main.yml');

    assertMatchesAll(
      content,
      [
        /name:\s*['"]?Verify PR originates from dev['"]?/,
        /github\.event_name\s*==\s*['"]pull_request['"]/,
        /github\.head_ref\s*!=\s*['"]dev['"]/,
      ],
      'security-main.yml Verify PR originates from dev'
    );
  });

  it('defines Terraform & Workflow Tests job running terraform test and node --test tests/security.workflows.test.js', () => {
    const content = readRepoFile('.github', 'workflows', 'security-main.yml');

    assertMatchesAll(
      content,
      [
        /name:\s*['"]?Terraform & Workflow Tests['"]?/,
        /terraform init -backend=false/,
        /terraform test/,
        /node --test tests\/security\.workflows\.test\.js/,
      ],
      'security-main.yml Terraform & Workflow Tests'
    );
  });

  it('defines SAST - SonarCloud Quality Gate job with SonarSource/sonarqube-scan-action and qualitygate.wait=true', () => {
    const content = readRepoFile('.github', 'workflows', 'security-main.yml');

    assertMatchesAll(
      content,
      [
        /name:\s*['"]?SAST - SonarCloud Quality Gate['"]?/,
        /SonarSource\/sonarqube-scan-action/,
        /sonar\.qualitygate\.wait=true/,
        /vars\.SONAR_ORGANIZATION/,
        /vars\.SONAR_PROJECT_KEY/,
      ],
      'security-main.yml SonarCloud job'
    );
  });

  it('defines SAST - Snyk IaC job with severity-threshold=high, dependabot[bot] handling, SARIF, and 30-day artifact', () => {
    const content = readRepoFile('.github', 'workflows', 'security-main.yml');

    assertMatchesAll(
      content,
      [
        /name:\s*['"]?SAST - Snyk IaC['"]?/,
        /snyk iac test/,
        /--severity-threshold=high/,
        /dependabot\[bot\]/,
        /SNYK_TOKEN/,
        /github\/codeql-action\/upload-sarif/,
        /name:\s*['"]?sast-snyk-iac-reports['"]?/,
        /retention-days:\s*30/,
      ],
      'security-main.yml Snyk IaC job'
    );
  });

  it('defines Compliance & IaC - Checkov & Trivy job with SARIF, checkov-report.xml, and 30-day iac-compliance-reports', () => {
    const content = readRepoFile('.github', 'workflows', 'security-main.yml');

    assertMatchesAll(
      content,
      [
        /name:\s*['"]?Compliance & IaC - Checkov & Trivy['"]?/,
        /checkov/i,
        /checkov-report\.xml/,
        /trivy/i,
        /github\/codeql-action\/upload-sarif/,
        /name:\s*['"]?iac-compliance-reports['"]?/,
        /retention-days:\s*30/,
      ],
      'security-main.yml Checkov & Trivy job'
    );
  });

  it('defines SBOM & Supply Chain - Syft & Grype job with CycloneDX, SPDX, .terraform.lock.hcl, Grype flags, and 30-day artifact', () => {
    const content = readRepoFile('.github', 'workflows', 'security-main.yml');

    assertMatchesAll(
      content,
      [
        /name:\s*['"]?SBOM & Supply Chain - Syft & Grype['"]?/,
        /syft/i,
        /cyclonedx/i,
        /spdx/i,
        /\.terraform\.lock\.hcl/,
        /grype/i,
        /severity-cutoff:\s*['"]?high['"]?/,
        /only-fixed:\s*['"]?true['"]?/,
        /name:\s*['"]?sbom-and-grype-reports['"]?/,
        /retention-days:\s*30/,
      ],
      'security-main.yml Syft & Grype job'
    );
  });

  it('defines Terraform Plan Preview (Read-Only) job using AWS OIDC and terraform plan with 30-day artifact', () => {
    const content = readRepoFile('.github', 'workflows', 'security-main.yml');

    assertMatchesAll(
      content,
      [
        /name:\s*['"]?Terraform Plan Preview \(Read-Only\)['"]?/,
        /id-token:\s*write/,
        /aws-actions\/configure-aws-credentials@v4/,
        /AWS_ROLE_ARN/,
        /terraform plan/,
        /retention-days:\s*30/,
      ],
      'security-main.yml Terraform Plan Preview job'
    );
  });
});

describe('4. Workflow 3: .github/workflows/release.yml', () => {
  it('triggers on release (published) and workflow_dispatch with boolean input apply_to_production defaulting to false', () => {
    const content = readRepoFile('.github', 'workflows', 'release.yml');

    assertMatchesAll(
      content,
      [
        /release:/,
        /types:\s*\[?\s*published\s*\]?/,
        /workflow_dispatch:/,
        /apply_to_production:/,
        /type:\s*boolean/,
        /default:\s*false/,
      ],
      'release.yml triggers'
    );
  });

  it('defines Build, SBOM, Scan & Sign Bundle job with SemVer/main check, tar.gz, Syft, Trivy/Checkov, Cosign, Attestations, SHA256SUMS, and release upload', () => {
    const content = readRepoFile('.github', 'workflows', 'release.yml');

    assertMatchesAll(
      content,
      [
        /name:\s*['"]?Build, SBOM, Scan & Sign Bundle['"]?/,
        /origin\/main/,
        /v\[0-9\]\+\\?\.\[0-9\]\+\\?\.\[0-9\]\+/,
        /orbit-iac-.*\.tar\.gz/,
        /docker\//,
        /user_data\.sh/,
        /syft/i,
        /trivy/i,
        /checkov/i,
        /cosign sign-blob/,
        /cosign verify-blob/,
        /actions\/attest-build-provenance/,
        /actions\/attest-sbom/,
        /SHA256SUMS\.txt/,
        /retention-days:\s*90/,
        /gh release upload/,
      ],
      'release.yml Build, SBOM, Scan & Sign Bundle job'
    );
  });

  it('defines Apply Terraform to Production (Manual Approval) job protected by environment: production, cosign verify-blob, OIDC, and terraform apply', () => {
    const content = readRepoFile('.github', 'workflows', 'release.yml');

    assertMatchesAll(
      content,
      [
        /name:\s*['"]?Apply Terraform to Production \(Manual Approval\)['"]?/,
        /environment:\s*['"]?production['"]?/,
        /cosign verify-blob/,
        /aws-actions\/configure-aws-credentials@v4/,
        /AWS_ROLE_ARN/,
        /terraform init/,
        /terraform plan -out=tfplan/,
        /terraform apply -auto-approve tfplan/,
      ],
      'release.yml Apply Terraform to Production job'
    );
  });
});

describe('5. Workflow 4: .github/workflows/drift.yml', () => {
  it('triggers on weekly schedule cron and workflow_dispatch, authenticates via OIDC, runs terraform plan -detailed-exitcode -no-color, uploads drift report, and fails on exit code 2', () => {
    const content = readRepoFile('.github', 'workflows', 'drift.yml');

    assertMatchesAll(
      content,
      [
        /schedule:/,
        /cron:/,
        /workflow_dispatch:/,
        /id-token:\s*write/,
        /aws-actions\/configure-aws-credentials@v4/,
        /terraform plan -detailed-exitcode -no-color/,
        /name:\s*['"]?terraform-drift-report['"]?/,
        /retention-days:\s*30/,
        /exit\s+2|==\s*2|-eq\s+2/,
      ],
      'drift.yml'
    );
  });
});

describe('6. Configs, Rulesets & Policy Script', () => {
  it('.tflint.hcl exists and enables aws ruleset', () => {
    const content = readRepoFile('.tflint.hcl');
    assertMatchesAll(content, [/plugin\s+"aws"/, /enabled\s*=\s*true/], '.tflint.hcl');
  });

  it('.coderabbit.yaml exists with language es-ES and Terraform/IAM/Security Group/Docker Compose rules', () => {
    const content = readRepoFile('.coderabbit.yaml');
    assertMatchesAll(
      content,
      [
        /language:\s*['"]?es-ES['"]?/,
        /terraform/i,
        /iam/i,
        /security\s*group/i,
        /docker/i,
      ],
      '.coderabbit.yaml'
    );
  });

  it('sonar-project.properties exists with sonar.sources=.', () => {
    const content = readRepoFile('sonar-project.properties');
    assertMatchesAll(content, [/sonar\.sources=\./], 'sonar-project.properties');
  });

  it('.github/CODEOWNERS exists and assigns @DRomothewriter', () => {
    const content = readRepoFile('.github', 'CODEOWNERS');
    assert.match(content, /@DRomothewriter/, '.github/CODEOWNERS must assign @DRomothewriter');
  });

  it('.github/dependabot.yml exists targeting dev for terraform and github-actions', () => {
    const content = readRepoFile('.github', 'dependabot.yml');
    assertMatchesAll(
      content,
      [
        /package-ecosystem:\s*['"]?terraform['"]?/,
        /package-ecosystem:\s*['"]?github-actions['"]?/,
        /target-branch:\s*['"]?dev['"]?/,
      ],
      '.github/dependabot.yml'
    );
  });

  it('.github/rulesets/main-ruleset.json is valid JSON with main branch and required status checks matching security-main.yml jobs', () => {
    const ruleset = readJson('.github', 'rulesets', 'main-ruleset.json');
    const includes = ruleset.conditions?.ref_name?.include || [];
    assert.ok(
      includes.includes('refs/heads/main'),
      'main-ruleset.json must target refs/heads/main'
    );

    const contexts = extractRequiredCheckContexts(ruleset);
    for (const expectedJob of [
      'Verify PR originates from dev',
      'Terraform & Workflow Tests',
      'SAST - SonarCloud Quality Gate',
      'SAST - Snyk IaC',
      'Compliance & IaC - Checkov & Trivy',
      'SBOM & Supply Chain - Syft & Grype',
    ]) {
      assert.ok(
        contexts.includes(expectedJob),
        `main-ruleset.json missing required status check: "${expectedJob}"`
      );
    }
  });

  it('.github/rulesets/dev-ruleset.json is valid JSON with dev branch and required status checks matching ci-dev.yml jobs', () => {
    const ruleset = readJson('.github', 'rulesets', 'dev-ruleset.json');
    const includes = ruleset.conditions?.ref_name?.include || [];
    assert.ok(
      includes.includes('refs/heads/dev'),
      'dev-ruleset.json must target refs/heads/dev'
    );

    const contexts = extractRequiredCheckContexts(ruleset);
    for (const expectedJob of [
      'Validate Branch, State Guard & Terraform',
      'Secret Scanning (TruffleHog)',
      'IaC Lint & Security (TFLint & Trivy)',
    ]) {
      assert.ok(
        contexts.includes(expectedJob),
        `dev-ruleset.json missing required status check: "${expectedJob}"`
      );
    }
  });

  it('.github/rulesets/tags-ruleset.json is valid JSON protecting refs/tags/v*', () => {
    const ruleset = readJson('.github', 'rulesets', 'tags-ruleset.json');
    const includes = ruleset.conditions?.ref_name?.include || [];
    assert.ok(
      includes.includes('refs/tags/v*'),
      'tags-ruleset.json must target refs/tags/v*'
    );
  });

  it('scripts/apply-github-policies.sh exists, is executable, and configures rulesets + production environment', () => {
    const scriptPath = repoPath('scripts', 'apply-github-policies.sh');
    const content = readRepoFile('scripts', 'apply-github-policies.sh');
    const stats = fs.statSync(scriptPath);
    assert.ok(
      (stats.mode & 0o111) !== 0,
      'scripts/apply-github-policies.sh must have executable permissions (+x)'
    );

    assertMatchesAll(
      content,
      [
        /main-ruleset\.json/,
        /dev-ruleset\.json/,
        /tags-ruleset\.json/,
        /environments\/production/,
      ],
      'scripts/apply-github-policies.sh'
    );
  });
});
