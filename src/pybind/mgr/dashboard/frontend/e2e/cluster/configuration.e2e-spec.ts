import { $ } from 'protractor';
import { ConfigurationPageHelper } from './configuration.po';

describe('Configuration page', () => {
  let configuration: ConfigurationPageHelper;

  beforeAll(() => {
    configuration = new ConfigurationPageHelper();
  });

  afterEach(async () => {
    await ConfigurationPageHelper.checkConsole();
  });

  describe('breadcrumb test', () => {
    beforeAll(async () => {
      await configuration.navigateTo();
    });

    it('should open and show breadcrumb', async () => {
      await configuration.waitTextToBePresent(configuration.getBreadcrumb(), 'Configuration');
    });
  });

  describe('fields check', () => {
    beforeAll(async () => {
      await configuration.navigateTo();
      await configuration.waitClickableAndClick(configuration.getFirstExpandCollapseElement());
    });

    it('should verify that selected footer increases when an entry is clicked', async () => {
      const selectedCount = await configuration.getTableSelectedCount();
      await expect(selectedCount).toBe(1);
    });

    it('should check that details table opens and tab is correct', async () => {
      await expect($('.table.table-striped.table-bordered').isDisplayed());
      await expect(configuration.getTabsCount()).toEqual(1);
      await expect(configuration.getTabText(0)).toEqual('Details');
    });
  });

  describe('edit configuration test', () => {
    const configName = 'client_cache_size';

    beforeAll(async () => {
      await configuration.navigateTo();
    });

    beforeEach(async () => {
      await configuration.clearTableSearchInput();
    });

    afterAll(async () => {
      await configuration.configClear(configName);
    });

    it('should click and edit a configuration and results should appear in the table', async () => {
      await configuration.edit(
        configName,
        ['global', '1'],
        ['mon', '2'],
        ['mgr', '3'],
        ['osd', '4'],
        ['mds', '5'],
        ['client', '6']
      );
    });

    it('should show only modified configurations', async () => {
      await configuration.filterTable('Modified', 'yes');
      expect(await configuration.getTableFoundCount()).toBe(1);
    });

    it('should hide all modified configurations', async () => {
      await configuration.filterTable('Modified', 'no');
      expect(await configuration.getTableFoundCount()).toBeGreaterThan(1);
    });
  });
});
