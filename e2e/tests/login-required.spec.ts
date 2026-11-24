// spec: specs/login.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';

test.describe('登录页表单必填项校验', () => {
  test('账号为空校验', async ({ page }) => {
    const accountInput = page.getByPlaceholder('账号');
    const passwordInput = page.getByPlaceholder('密码');
    const loginButton = page.getByRole('button', { name: /登\s*录/ });
    const accountItem = page.locator('.el-form-item').filter({ has: accountInput });
    const passwordItem = page.locator('.el-form-item').filter({ has: passwordInput });

    // 1. 打开登录页，等待登录表单渲染完成（浏览器可能因「记住密码」自动回填）
    await page.goto('/login');
    await expect(accountInput).toBeVisible();
    await expect(passwordInput).toBeVisible();
    await expect(loginButton).toBeVisible();

    // 2. 定位账号输入框，清空其内容并确认值为空
    await accountInput.click();
    await accountInput.fill('');
    await expect(accountInput).toHaveValue('');

    // 3. 定位密码输入框，输入占位值 test123456
    await passwordInput.fill('test123456');
    await expect(passwordInput).toHaveValue('test123456');

    // 4. 点击文本为「登 录」的按钮
    await loginButton.click();

    // 预期 1: 账号输入框下方出现行内错误提示「请输入您的账号」
    await expect(accountItem.locator('.el-form-item__error')).toHaveText('请输入您的账号');
    await expect(page.getByText('请输入您的账号', { exact: true })).toBeVisible();

    // 预期 2: 账号表单项标记 is-error，密码表单项无错误文案
    await expect(accountItem).toHaveClass(/is-error/);
    await expect(passwordItem.locator('.el-form-item__error')).toHaveCount(0);

    // 预期 3: 不出现 toast / 全局消息 / 弹窗
    await expect(page.locator('.el-message, .el-notification')).toHaveCount(0);

    // 预期 4: 仍停留在登录页，URL 仍为 /login
    await expect(page).toHaveURL(/\/login$/);
  });

  test('密码为空校验', async ({ page }) => {
    const accountInput = page.getByPlaceholder('账号');
    const passwordInput = page.getByPlaceholder('密码');
    const loginButton = page.getByRole('button', { name: /登\s*录/ });
    const accountItem = page.locator('.el-form-item').filter({ has: accountInput });
    const passwordItem = page.locator('.el-form-item').filter({ has: passwordInput });

    // 1. 打开登录页，等待登录表单渲染完成（浏览器可能因「记住密码」自动回填）
    await page.goto('/login');
    await expect(accountInput).toBeVisible();
    await expect(passwordInput).toBeVisible();
    await expect(loginButton).toBeVisible();

    // 2. 定位账号输入框，输入占位值 testuser
    await accountInput.fill('testuser');
    await expect(accountInput).toHaveValue('testuser');

    // 3. 定位密码输入框，清空其内容并确认值为空
    await passwordInput.click();
    await passwordInput.fill('');
    await expect(passwordInput).toHaveValue('');

    // 4. 点击文本为「登 录」的按钮
    await loginButton.click();

    // 预期 1: 密码输入框下方出现行内错误提示「请输入您的密码」
    await expect(passwordItem.locator('.el-form-item__error')).toHaveText('请输入您的密码');
    await expect(page.getByText('请输入您的密码', { exact: true })).toBeVisible();

    // 预期 2: 密码表单项标记 is-error，账号表单项无错误文案
    await expect(passwordItem).toHaveClass(/is-error/);
    await expect(accountItem.locator('.el-form-item__error')).toHaveCount(0);

    // 预期 3: 不出现 toast / 全局消息 / 弹窗
    await expect(page.locator('.el-message, .el-notification')).toHaveCount(0);

    // 预期 4: 仍停留在登录页，URL 仍为 /login
    await expect(page).toHaveURL(/\/login$/);
  });
});
