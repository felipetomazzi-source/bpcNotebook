// Run with playwright-cli -s=bpc-notebook run-code --filename=tests/browser-workflow.js
// Creates a fresh local demo notebook and tests the visible UI workflow.
async (page) => {
  const errors=[];
  page.on('pageerror',error=>errors.push(error.message));
  await page.getByRole('button',{name:'Open allocation demo',exact:true}).click();
  await page.getByRole('button',{name:'Run all',exact:true}).click();
  await page.getByText('succeeded · 100%',{exact:true}).waitFor();
  await page.getByRole('gridcell',{name:'CC100',exact:true}).waitFor();
  await page.getByRole('button',{name:'Next page',exact:true}).click();
  await page.getByRole('gridcell',{name:'CC300',exact:true}).waitFor();
  await page.getByRole('button',{name:'View snapshot',exact:true}).click();
  await page.getByRole('dialog',{name:'Frozen execution snapshot'}).waitFor();
  const snapshot=await page.getByRole('dialog').getByRole('textbox').inputValue();
  if(!snapshot.includes('120000') || !snapshot.includes('io->emit'))throw new Error('Source/input snapshot missing');
  await page.getByRole('button',{name:'Close',exact:true}).click();
  await page.locator('input[value="120000"]').fill('240000');
  await page.locator('input[value="120000"]').press('Tab');
  await page.getByRole('button',{name:'Save version',exact:true}).click();
  await page.getByText('Stale output',{exact:true}).first().waitFor();
  await page.getByRole('button',{name:'Versions',exact:true}).click();
  await page.getByRole('dialog',{name:'Source and input history'}).waitFor();
  await page.getByRole('dialog').getByText('Revision 2 · LOCAL_DEVELOPER',{exact:true}).waitFor();
  await page.getByRole('button',{name:'Close',exact:true}).click();
  await page.getByRole('button',{name:'Retry snapshot',exact:true}).click();
  await page.getByText('succeeded · 100%',{exact:true}).waitFor();
  await page.getByRole('button',{name:'View snapshot',exact:true}).click();
  const retry=await page.getByRole('dialog').getByRole('textbox').inputValue();
  if(!retry.includes('120000'))throw new Error('Retry did not preserve old inputs');
  await page.getByRole('button',{name:'Close',exact:true}).click();
  if(errors.length)throw new Error(errors.join('\n'));
  return {workflow:'create/run/page/snapshot/edit/save/history/retry',passed:true};
}
