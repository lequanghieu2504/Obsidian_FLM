function detectPage() {
  const url = new URL(location.href);
  const isCurriculumDetails = /\/gui\/role\/student\/CurriculumDetails\/?$/i.test(url.pathname);
  const isComboManagement = /\/Compo\/ViewComBo\/?$/i.test(url.pathname);
  if (url.hostname.toLowerCase() !== 'flm.fpt.edu.vn' || (!isCurriculumDetails && !isComboManagement)) {
    return { valid: false };
  }
  const curriculumId = isCurriculumDetails
    ? url.searchParams.get('curid')
    : url.searchParams.get('cur_id');
  if (!curriculumId || !/^\d+$/.test(curriculumId)) return { valid: false };

  // Keep this entry point dependency-free. Manifest content scripts are loaded
  // as classic scripts, so a Rollup-generated ESM import would make Chrome
  // reject the entire file before this listener can be registered.
  const values: Record<string, string> = {};
  for (const row of document.querySelectorAll('tr')) {
    const cells = Array.from(row.children);
    if (cells.length !== 2) continue;
    const key = (cells[0].textContent ?? '').replace(/\s+/g, ' ').trim().replace(/:$/, '');
    const value = (cells[1].textContent ?? '').replace(/\s+/g, ' ').trim();
    if (key && value) values[key.toLowerCase().replace(/[^a-z0-9]+/g, '')] = value;
  }
  return {
    // The live FLM markup varies between deployments and can be populated after
    // document_idle. The URL and numeric curriculum ID are the stable contract;
    // the background crawler validates the fetched response before exporting.
    valid: true,
    curriculumId,
    curriculumCode: values.curriculumcode,
    curriculumName: values.name ?? values.curriculumname,
  };
}

chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  if (message?.type === 'DETECT_CURRICULUM_PAGE') sendResponse(detectPage());
});
