import { expect, test, type Page } from '@playwright/test';

const chefEmail = process.env.E2E_CHEF_EMAIL;
const chefPassword = process.env.E2E_CHEF_PASSWORD;
const managerEmail = process.env.E2E_MANAGER_EMAIL;
const managerPassword = process.env.E2E_MANAGER_PASSWORD;

const credentialsAvailable = Boolean(
  chefEmail && chefPassword && managerEmail && managerPassword,
);

async function login(page: Page, email: string, password: string, route: string) {
  await page.goto('/login');
  await page.getByLabel('Email').fill(email);
  await page.getByLabel('Mot de passe').fill(password);
  await page.getByRole('button', { name: 'Se connecter' }).click();
  await expect(page).toHaveURL(new RegExp(`${route}(?:[/?#]|$)`));
}

test.describe('pilot task workflow', () => {
  test.skip(!credentialsAvailable, 'Set the E2E pilot account variables to run this test.');

  test('chef claims and corrects with proof, manager verifies', async ({ browser }) => {
    const chefContext = await browser.newContext();
    const chefPage = await chefContext.newPage();
    await login(chefPage, chefEmail!, chefPassword!, '/chef');

    const candidate = chefPage.locator('[data-analysis-id]').filter({
      has: chefPage.getByRole('button', { name: 'Pris en charge' }),
    }).first();
    await expect(candidate).toBeVisible();
    const analysisId = await candidate.getAttribute('data-analysis-id');
    expect(analysisId).toBeTruthy();

    await candidate.getByRole('button', { name: 'Pris en charge' }).click();
    await expect(candidate.getByText('Pris en charge', { exact: true })).toBeVisible();

    await candidate.locator('input[type="file"]').setInputFiles({
      name: 'preuve-pilote.png',
      mimeType: 'image/png',
      buffer: Buffer.from(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Y9Z4xIAAAAASUVORK5CYII=',
        'base64',
      ),
    });
    await candidate.getByRole('button', { name: 'Corrige' }).click();
    await expect(candidate.getByText(/Corrige/)).toBeVisible();

    const managerContext = await browser.newContext();
    const managerPage = await managerContext.newPage();
    await login(managerPage, managerEmail!, managerPassword!, '/manager');

    const managerTask = managerPage.locator(`[data-analysis-id="${analysisId}"]`);
    await expect(managerTask).toBeVisible();
    await expect(managerTask.getByText(/Corrige/)).toBeVisible();
    await managerTask.getByRole('button', { name: 'Valider' }).click();
    await expect(managerTask.getByText(/Valide/)).toBeVisible();

    await managerContext.close();
    await chefContext.close();
  });
});
